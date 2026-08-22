#!/usr/bin/env python3
"""Owned refinement checker for a deliberately small Haskell source fragment.

The checked artifact is an actual GHC-compilable function equation carrying an
``amoebius-refinement`` block comment.  This module owns parsing, the linear
integer/boolean SMT translation, postcondition preservation, and correspondence
to an authored Model-invariant registry.  Z3 is injected by absolute path.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parent.parent
ANNOTATION = re.compile(r"\{-@\s*amoebius-refinement\s*\n(?P<body>.*?)@-\}", re.DOTALL)
TOKEN = re.compile(r"\s*(?:(?P<int>[0-9]+)|(?P<name>[A-Za-z_][A-Za-z0-9_]*)|(?P<op><=|>=|==|/=|&&|\|\||[()+\-<>]))")


class RefinementFailure(RuntimeError):
    pass


@dataclass(frozen=True)
class Expr:
    operator: str
    arguments: tuple["Expr", ...] = ()
    value: str = ""


@dataclass(frozen=True)
class RefinementSource:
    path: Path
    model: str
    invariant: str
    function: str
    arguments: tuple[str, ...]
    precondition: Expr
    postcondition: Expr
    body: Expr
    function_line: int
    source_digest: str


@dataclass(frozen=True)
class Expected:
    source: str
    model: str
    invariant: str
    function: str
    expected: str
    reason: str
    required: str
    line: int


@dataclass(frozen=True)
class Result:
    source: str
    function: str
    status: str
    reason: str
    line: int
    source_digest: str
    solver_model: str


class Parser:
    def __init__(self, text: str) -> None:
        self.tokens = self._tokens(text)
        self.offset = 0

    @staticmethod
    def _tokens(text: str) -> list[str]:
        tokens: list[str] = []
        offset = 0
        while offset < len(text):
            match = TOKEN.match(text, offset)
            if match is None:
                raise RefinementFailure(f"unsupported expression syntax at {text[offset:]!r}")
            tokens.append(match.group("int") or match.group("name") or match.group("op"))
            offset = match.end()
        return tokens

    def parse(self) -> Expr:
        expression = self.parse_if()
        if self.offset != len(self.tokens):
            raise RefinementFailure(f"unexpected token {self.tokens[self.offset]!r}")
        return expression

    def peek(self, value: str) -> bool:
        return self.offset < len(self.tokens) and self.tokens[self.offset] == value

    def take(self, value: str | None = None) -> str:
        if self.offset >= len(self.tokens):
            raise RefinementFailure("unexpected end of expression")
        token = self.tokens[self.offset]
        if value is not None and token != value:
            raise RefinementFailure(f"expected {value!r}, got {token!r}")
        self.offset += 1
        return token

    def parse_if(self) -> Expr:
        if self.peek("if"):
            self.take("if")
            condition = self.parse_or()
            self.take("then")
            when_true = self.parse_if()
            self.take("else")
            when_false = self.parse_if()
            return Expr("if", (condition, when_true, when_false))
        return self.parse_or()

    def parse_or(self) -> Expr:
        expression = self.parse_and()
        while self.peek("||"):
            self.take()
            expression = Expr("or", (expression, self.parse_and()))
        return expression

    def parse_and(self) -> Expr:
        expression = self.parse_comparison()
        while self.peek("&&"):
            self.take()
            expression = Expr("and", (expression, self.parse_comparison()))
        return expression

    def parse_comparison(self) -> Expr:
        expression = self.parse_addition()
        if self.offset < len(self.tokens) and self.tokens[self.offset] in {"<", "<=", ">", ">=", "==", "/="}:
            operator = self.take()
            expression = Expr(operator, (expression, self.parse_addition()))
        return expression

    def parse_addition(self) -> Expr:
        expression = self.parse_unary()
        while self.offset < len(self.tokens) and self.tokens[self.offset] in {"+", "-"}:
            operator = self.take()
            expression = Expr(operator, (expression, self.parse_unary()))
        return expression

    def parse_unary(self) -> Expr:
        if self.peek("not"):
            self.take()
            return Expr("not", (self.parse_unary(),))
        if self.peek("-"):
            self.take()
            return Expr("negate", (self.parse_unary(),))
        return self.parse_primary()

    def parse_primary(self) -> Expr:
        token = self.take()
        if token == "(":
            expression = self.parse_if()
            self.take(")")
            return expression
        if token.isdigit():
            return Expr("integer", value=token)
        if token in {"true", "false"}:
            return Expr("boolean", value=token)
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", token):
            return Expr("variable", value=token)
        raise RefinementFailure(f"unsupported primary token {token!r}")


def parse_expression(text: str) -> Expr:
    return Parser(text.strip()).parse()


def parse_source(path: Path) -> RefinementSource:
    text = path.read_text(encoding="utf-8")
    match = ANNOTATION.search(text)
    if match is None:
        raise RefinementFailure(f"{path}: missing amoebius-refinement annotation")
    fields: dict[str, str] = {}
    for raw_line in match.group("body").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        key, separator, value = line.partition(":")
        if not separator or not key.strip() or not value.strip() or key.strip() in fields:
            raise RefinementFailure(f"{path}: malformed or duplicate annotation line {line!r}")
        fields[key.strip()] = value.strip()
    required = {"model", "invariant", "function", "arguments", "pre", "post"}
    if set(fields) != required:
        raise RefinementFailure(f"{path}: annotation fields {sorted(fields)} != {sorted(required)}")
    arguments = tuple(part.strip() for part in fields["arguments"].split(",") if part.strip())
    if not arguments or len(set(arguments)) != len(arguments):
        raise RefinementFailure(f"{path}: arguments must be a non-empty unique list")
    function = re.escape(fields["function"])
    equation = re.compile(
        rf"^(?P<name>{function})\s+(?P<arguments>[A-Za-z_][A-Za-z0-9_]*(?:\s+[A-Za-z_][A-Za-z0-9_]*)*)\s*=\s*(?P<body>[^\n]+)$",
        re.MULTILINE,
    ).search(text)
    if equation is None:
        raise RefinementFailure(f"{path}: annotated function equation is absent or outside the one-line fragment")
    equation_arguments = tuple(equation.group("arguments").split())
    if equation_arguments != arguments:
        raise RefinementFailure(f"{path}: annotation arguments {arguments} != equation {equation_arguments}")
    signature = re.search(rf"^{function}\s*::\s*(?P<signature>[^\n]+)$", text, re.MULTILINE)
    expected_signature = " -> ".join(["Integer"] * (len(arguments) + 1))
    if signature is None or " ".join(signature.group("signature").split()) != expected_signature:
        raise RefinementFailure(f"{path}: signature must be {expected_signature}")
    function_line = text[: equation.start()].count("\n") + 1
    return RefinementSource(
        path=path,
        model=fields["model"],
        invariant=fields["invariant"],
        function=fields["function"],
        arguments=arguments,
        precondition=parse_expression(fields["pre"]),
        postcondition=parse_expression(fields["post"]),
        body=parse_expression(equation.group("body")),
        function_line=function_line,
        source_digest=hashlib.sha256(text.encode("utf-8")).hexdigest(),
    )


def translate(expression: Expr, admitted: set[str]) -> tuple[str, str]:
    operator = expression.operator
    if operator == "integer":
        return "Int", expression.value
    if operator == "boolean":
        return "Bool", expression.value
    if operator == "variable":
        if expression.value not in admitted:
            raise RefinementFailure(f"unbound refinement variable {expression.value}")
        return "Int", expression.value
    if operator in {"+", "-"}:
        left_sort, left = translate(expression.arguments[0], admitted)
        right_sort, right = translate(expression.arguments[1], admitted)
        require_sort("Int", left_sort, operator)
        require_sort("Int", right_sort, operator)
        return "Int", f"({operator} {left} {right})"
    if operator == "negate":
        value_sort, value = translate(expression.arguments[0], admitted)
        require_sort("Int", value_sort, operator)
        return "Int", f"(- {value})"
    if operator in {"<", "<=", ">", ">="}:
        left_sort, left = translate(expression.arguments[0], admitted)
        right_sort, right = translate(expression.arguments[1], admitted)
        require_sort("Int", left_sort, operator)
        require_sort("Int", right_sort, operator)
        return "Bool", f"({operator} {left} {right})"
    if operator in {"==", "/="}:
        left_sort, left = translate(expression.arguments[0], admitted)
        right_sort, right = translate(expression.arguments[1], admitted)
        require_sort(left_sort, right_sort, operator)
        smt = "=" if operator == "==" else "distinct"
        return "Bool", f"({smt} {left} {right})"
    if operator in {"and", "or"}:
        left_sort, left = translate(expression.arguments[0], admitted)
        right_sort, right = translate(expression.arguments[1], admitted)
        require_sort("Bool", left_sort, operator)
        require_sort("Bool", right_sort, operator)
        smt = "and" if operator == "and" else "or"
        return "Bool", f"({smt} {left} {right})"
    if operator == "not":
        value_sort, value = translate(expression.arguments[0], admitted)
        require_sort("Bool", value_sort, operator)
        return "Bool", f"(not {value})"
    if operator == "if":
        condition_sort, condition = translate(expression.arguments[0], admitted)
        true_sort, when_true = translate(expression.arguments[1], admitted)
        false_sort, when_false = translate(expression.arguments[2], admitted)
        require_sort("Bool", condition_sort, operator)
        require_sort(true_sort, false_sort, operator)
        return true_sort, f"(ite {condition} {when_true} {when_false})"
    raise RefinementFailure(f"unsupported expression operator {operator}")


def require_sort(expected: str, actual: str, operator: str) -> None:
    if expected != actual:
        raise RefinementFailure(f"{operator} expected {expected}, got {actual}")


def render_query(arguments: Iterable[str], assertions: Iterable[str]) -> str:
    declarations = [f"(declare-const {name} Int)" for name in arguments]
    declarations.append("(declare-const result Int)")
    return "\n".join(
        ["(set-option :produce-models true)", "(set-option :timeout 10000)", "(set-logic QF_LIA)"]
        + declarations
        + [f"(assert {assertion})" for assertion in assertions]
        + ["(check-sat)"]
    ) + "\n"


def solve(z3: Path, query: str) -> tuple[str, str]:
    if not z3.is_absolute() or not z3.is_file():
        raise RefinementFailure(f"solver path is not an absolute file: {z3}")
    result = subprocess.run(
        [str(z3), "-in", "-smt2"], input=query, text=True, capture_output=True, check=False
    )
    status = next((line.strip() for line in result.stdout.splitlines()
                   if line.strip() in {"sat", "unsat", "unknown"}), "")
    if status not in {"sat", "unsat"}:
        raise RefinementFailure(f"solver produced {status or 'no status'}: {result.stdout}{result.stderr}")
    if status == "unsat":
        return status, ""
    model = subprocess.run(
        [str(z3), "-in", "-smt2"], input=query + "(get-model)\n",
        text=True, capture_output=True, check=False
    )
    return status, model.stdout + model.stderr


def weaken_conjoined_precondition(expression: Expr) -> Expr:
    if expression.operator == "and":
        return expression.arguments[0]
    return expression


def check_refinement(
    z3: Path,
    source: RefinementSource,
    invariant_registry: dict[tuple[str, str], Expr],
    mutant: str = "",
) -> Result:
    invariant = invariant_registry.get((source.model, source.invariant))
    if invariant is None:
        return result(source, "unknown-invariant", "annotation names no registered model invariant")
    admitted = set(source.arguments) | {"result"}
    post_sort, post = translate(source.postcondition, admitted)
    invariant_sort, model_post = translate(invariant, admitted)
    require_sort("Bool", post_sort, "postcondition")
    require_sort("Bool", invariant_sort, "model invariant")
    if mutant != "skip-correspondence":
        status, solver_model = solve(z3, render_query(source.arguments, [post, f"(not {model_post})"]))
        if status == "sat":
            return result(source, "correspondence-mismatch",
                          "postcondition does not imply the registered model invariant", solver_model)
    precondition = (
        weaken_conjoined_precondition(source.precondition)
        if mutant == "drop-precondition-conjunct" else source.precondition
    )
    pre_sort, pre = translate(precondition, admitted)
    body_sort, body = translate(source.body, set(source.arguments))
    require_sort("Bool", pre_sort, "precondition")
    require_sort("Int", body_sort, "function body")
    proof_post = "true" if mutant == "weaken-postcondition" else post
    status, solver_model = solve(
        z3, render_query(source.arguments, [pre, f"(= result {body})", f"(not {proof_post})"])
    )
    if status == "sat":
        return result(source, "postcondition-counterexample",
                      "function body does not establish its postcondition", solver_model)
    return result(source, "proved", "postcondition preserved and correspondence established")


def result(source: RefinementSource, status: str, reason: str, solver_model: str = "") -> Result:
    return Result(
        source=str(source.path.relative_to(ROOT)),
        function=source.function,
        status=status,
        reason=reason,
        line=source.function_line,
        source_digest=source.source_digest,
        solver_model=solver_model,
    )


def read_expected(path: Path) -> list[Expected]:
    with path.open(encoding="utf-8", newline="") as handle:
        return [Expected(
            source=row["source"], model=row["model"], invariant=row["invariant"],
            function=row["function"], expected=row["expected"], reason=row["reason"],
            required=row["required"], line=int(row["line"]),
        ) for row in csv.DictReader(handle, delimiter="\t")]


def read_invariants(path: Path) -> dict[tuple[str, str], Expr]:
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    registry: dict[tuple[str, str], Expr] = {}
    for row in rows:
        key = (row["model"], row["invariant"])
        if key in registry:
            raise RefinementFailure(f"duplicate model invariant {key}")
        registry[key] = parse_expression(row["post"])
    return registry


def compile_source(ghc: Path, source: Path, output: Path) -> None:
    if not ghc.is_absolute() or not ghc.is_file():
        raise RefinementFailure(f"compiler path is not an absolute file: {ghc}")
    output.mkdir(parents=True, exist_ok=True)
    compiled = subprocess.run(
        [str(ghc), "-fno-code", "-fforce-recomp", f"-odir={output}", f"-hidir={output}", str(source)],
        cwd=ROOT, text=True, capture_output=True, check=False,
    )
    if compiled.returncode != 0:
        raise RefinementFailure(f"GHC rejected {source}: {compiled.stdout}{compiled.stderr}")


def write_results(path: Path, observations: list[Result], expected: list[Expected], required_count: int) -> None:
    count = lambda status: sum(observation.status == status for observation in observations)
    required_pairs = {(row.model, row.invariant) for row in expected if row.required == "yes"}
    covered_pairs = {
        (row.model, row.invariant)
        for row, observation in zip(expected, observations)
        if row.required == "yes" and observation.status == "proved"
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join([
        "metric\tvalue",
        f"fixture-count\t{len(observations)}",
        f"proved-count\t{count('proved')}",
        f"postcondition-counterexample-count\t{count('postcondition-counterexample')}",
        f"correspondence-mismatch-count\t{count('correspondence-mismatch')}",
        f"unknown-invariant-count\t{count('unknown-invariant')}",
        f"required-invariant-count\t{required_count}",
        f"covered-invariant-count\t{len(covered_pairs & required_pairs)}",
        f"ghc-compiled-count\t{len(observations)}",
        f"diagnostic-count\t{sum(observation.status != 'proved' for observation in observations)}",
        f"source-digest-count\t{sum(len(observation.source_digest) == 64 for observation in observations)}",
    ]) + "\n", encoding="utf-8")


def evaluate(
    z3: Path,
    ghc: Path,
    oracle_path: Path,
    invariant_path: Path,
    results_path: Path | None,
    mutant: str,
) -> list[Result]:
    expected = read_expected(oracle_path)
    invariants = read_invariants(invariant_path)
    sources = [parse_source(ROOT / row.source) for row in expected]
    if len({row.source for row in expected}) != len(expected):
        raise RefinementFailure("refinement oracle repeats a source")
    if {(source.model, source.invariant, source.function) for source in sources} != {
        (row.model, row.invariant, row.function) for row in expected
    }:
        raise RefinementFailure("source annotations do not match the correspondence oracle")
    required_pairs = {(row.model, row.invariant) for row in expected if row.required == "yes"}
    if required_pairs != set(invariants):
        raise RefinementFailure(
            f"required correspondence pairs {sorted(required_pairs)} != invariant registry {sorted(invariants)}"
        )
    build_root = ROOT / ".build/tmp/refinement-checker-ghc"
    for source in sources:
        compile_source(ghc, source.path, build_root)
    observations = [check_refinement(z3, source, invariants, mutant) for source in sources]
    for row, observation in zip(expected, observations):
        if observation.status != row.expected:
            raise RefinementFailure(
                f"{row.function} status: expected {row.expected!r}, got {observation.status!r}"
            )
        if observation.reason != row.reason:
            raise RefinementFailure(
                f"{row.function} reason: expected {row.reason!r}, got {observation.reason!r}"
            )
        if observation.line != row.line:
            raise RefinementFailure(
                f"{row.function} line: expected {row.line}, got {observation.line}"
            )
    if results_path is not None:
        write_results(results_path, observations, expected, len(invariants))
    return observations


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--z3", type=Path, required=True)
    parser.add_argument("--ghc", type=Path, required=True)
    parser.add_argument("--oracle", type=Path, default=ROOT / "test/oracle/refinement_checker/functions.tsv")
    parser.add_argument("--invariants", type=Path, default=ROOT / "test/oracle/refinement_checker/model_invariants.tsv")
    parser.add_argument("--results", type=Path)
    parser.add_argument("--mutant", choices=("", "drop-precondition-conjunct", "skip-correspondence", "weaken-postcondition"), default="")
    options = parser.parse_args()
    try:
        observations = evaluate(
            options.z3, options.ghc, options.oracle, options.invariants,
            options.results, options.mutant,
        )
    except (OSError, ValueError, RefinementFailure) as problem:
        print(f"refinement-checker: FAIL: {problem}")
        return 1
    print(
        "refinement-checker-spec: PASS "
        f"({len(observations)} functions, 2 invariant correspondences, 3 specific negatives)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
