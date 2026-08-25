let legal = ./phase_49_determinism_repro.dhall

in  legal with resolvedProgram = "metric=minimize;stage=seeded-sha256;input=sha256:base"
