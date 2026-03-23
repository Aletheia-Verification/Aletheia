# Aletheia Gatekeeper — CI/CD Verification Gate

Headless behavioral verification image. Runs the full Engine + Shadow Diff
pipeline from the command line. Designed to be dropped into any CI/CD system
as a build gate: **exit 0 = VERIFIED, exit 1 = DRIFT, exit 2 = ERROR**.

No web server. No frontend. No browser. Just the engine.

---

## Build

```bash
# From the repository root:
docker build -f docker/Dockerfile.gatekeeper -t aletheia-gatekeeper .
```

---

## Usage

```bash
docker run --rm \
  -v $(pwd):/data \
  aletheia-gatekeeper \
    --source /data/program.cbl \
    --input  /data/input.dat \
    --output /data/output.dat
```

Layout is auto-generated from the COBOL DATA DIVISION. To supply a custom layout:

```bash
docker run --rm \
  -v $(pwd):/data \
  aletheia-gatekeeper \
    --source /data/program.cbl \
    --input  /data/input.dat \
    --output /data/output.dat \
    --layout /data/layout.json
```

### Options

| Flag | Required | Description |
|------|----------|-------------|
| `--source` | Yes | Path to COBOL source file |
| `--input` | Yes | Mainframe input data file (fixed-width) |
| `--output` | Yes | Mainframe output data file (fixed-width) |
| `--layout` | No | Layout JSON (auto-generated if omitted) |
| `--compiler-trunc` | No | TRUNC mode: `STD`, `BIN`, or `OPT` |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | **VERIFIED** — zero drift, all records match |
| 1 | **DRIFT DETECTED** or **REQUIRES MANUAL REVIEW** |
| 2 | **ERROR** — missing file, parse failure, etc. |

---

## Jenkins Pipeline

```groovy
pipeline {
    agent any

    stages {
        stage('Behavioral Verification') {
            steps {
                sh '''
                    docker run --rm \
                      -v ${WORKSPACE}:/data \
                      aletheia-gatekeeper \
                        --source /data/src/${COBOL_PROGRAM}.cbl \
                        --input  /data/testdata/${COBOL_PROGRAM}_input.dat \
                        --output /data/testdata/${COBOL_PROGRAM}_output.dat
                '''
            }
        }
    }

    post {
        failure {
            echo 'BEHAVIORAL VERIFICATION FAILED — drift detected or manual review required.'
        }
        success {
            echo 'BEHAVIORAL VERIFICATION PASSED — zero drift confirmed.'
        }
    }
}
```

---

## GitLab CI

```yaml
behavioral-verification:
  stage: test
  image: aletheia-gatekeeper
  variables:
    COBOL_PROGRAM: "LOAN_INTEREST"
  script:
    - python cli_entry.py verify
        --source src/${COBOL_PROGRAM}.cbl
        --input  testdata/${COBOL_PROGRAM}_input.dat
        --output testdata/${COBOL_PROGRAM}_output.dat
  rules:
    - changes:
        - "src/**/*.cbl"
        - "src/**/*.cob"
```

> **Note:** Because `aletheia-gatekeeper` has `ENTRYPOINT ["python", "cli_entry.py", "verify"]`,
> using it directly as the GitLab job image means the entrypoint runs automatically.
> The `script` above overrides the entrypoint for explicit control. Choose whichever
> pattern fits your workflow.

---

## GitHub Actions

```yaml
jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Behavioral Verification
        run: |
          docker run --rm \
            -v ${{ github.workspace }}:/data \
            aletheia-gatekeeper \
              --source /data/src/${{ env.COBOL_PROGRAM }}.cbl \
              --input  /data/testdata/${{ env.COBOL_PROGRAM }}_input.dat \
              --output /data/testdata/${{ env.COBOL_PROGRAM }}_output.dat
        env:
          COBOL_PROGRAM: LOAN_INTEREST
```

---

## Batch Verification (Multiple Programs)

Loop over all COBOL programs in a directory. The pipeline fails on the first drift:

```bash
#!/bin/bash
set -e

for cbl in src/*.cbl; do
    name=$(basename "$cbl" .cbl)
    echo "=== Verifying $name ==="
    docker run --rm \
      -v $(pwd):/data \
      aletheia-gatekeeper \
        --source "/data/src/${name}.cbl" \
        --input  "/data/testdata/${name}_input.dat" \
        --output "/data/testdata/${name}_output.dat"
done

echo "ALL PROGRAMS VERIFIED"
```

---

## License Volume

If running in `strict` license mode, mount the license directory:

```bash
docker run --rm \
  -v $(pwd):/data \
  -v $(pwd)/license:/app/license:ro \
  -e ALETHEIA_LICENSE_MODE=strict \
  aletheia-gatekeeper \
    --source /data/program.cbl \
    --input  /data/input.dat \
    --output /data/output.dat
```
