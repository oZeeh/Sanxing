#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <new-results-directory>" >&2
  exit 2
fi

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=$1
if [ -e "$output_dir" ]; then
  echo "results directory already exists: $output_dir" >&2
  exit 1
fi

cd "$repo_root"
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "definitive experiments require a clean Git revision" >&2
  exit 1
fi

commit=$(git rev-parse --short HEAD)
run_id=$(date -u +%Y%m%dT%H%M%SZ)-$commit
target_label=$(uname -s)-$(uname -m)
mkdir -p "$output_dir/raw" "$output_dir/summary" "$output_dir/trajectories" "$output_dir/figures"

python3 tools/analyze_experiments.py manifest "$output_dir/manifest.json" "$run_id" "$target_label"

odin run engine/src -o:speed -- benchmark "$output_dir/raw/performance.jsonl" \
  --summary "$output_dir/summary/performance.csv" \
  --solver both --thetas 0.25,0.5,1.0 \
  --counts 100,500,1000,5000,10000 --steps 10 --samples 10 --warmups 2 \
  --run-id "$run_id" --target-label "$target_label" --opt-label speed

odin run engine/src -o:speed -- accuracy "$output_dir/raw/accuracy.jsonl" \
  --summary "$output_dir/summary/accuracy.csv" \
  --counts 100,500,1000,5000,10000 --thetas 0,0.25,0.5,1.0 \
  --run-id "$run_id" --target-label "$target_label" --opt-label speed

for name in two_body_orbit_100 two_body_orbit_200 two_body_orbit_400 \
  burrau_base_001 burrau_perturbed_001 burrau_base_0005 burrau_perturbed_0005; do
  odin run engine/src -o:speed -- simulate \
    "engine/examples/experiments/$name.json" \
    "$output_dir/trajectories/$name.jsonl" \
    --diagnostics "$output_dir/trajectories/$name-diagnostics.jsonl"
done

python3 tools/analyze_experiments.py analyze "$output_dir"
echo "completed thesis experiment bundle: $output_dir"
