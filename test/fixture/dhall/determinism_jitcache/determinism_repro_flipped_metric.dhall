let legal = ./phase_48_determinism_repro.dhall

in  legal with resolvedProgram = "metric=minimize;stage=seeded-sha256;input=sha256:base"
