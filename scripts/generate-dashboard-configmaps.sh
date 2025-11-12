#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DASHBOARDS_DIR="${REPO_ROOT}/apps/grafana/base/dashboards"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Grafana Dashboard ConfigMap Generator ===${NC}"
echo ""

# Process each JSON file in the dashboards directory
for json_file in "${DASHBOARDS_DIR}"/*.json; do
    if [ ! -f "$json_file" ]; then
        continue
    fi

    filename=$(basename "$json_file")
    name="${filename%.json}"
    configmap_file="${DASHBOARDS_DIR}/${name}-configmap.yaml"

    echo -e "${YELLOW}Generating ConfigMap for: ${filename}${NC}"

    # Create ConfigMap YAML
    cat > "${configmap_file}" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${name}
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
    app.kubernetes.io/name: grafana
    app.kubernetes.io/part-of: monitoring-stack
data:
  ${filename}: |
EOF

    # Indent JSON content by 4 spaces and append to ConfigMap
    sed 's/^/    /' "$json_file" >> "${configmap_file}"

    echo -e "${GREEN}✓ Created: ${configmap_file}${NC}"
done

echo ""
echo -e "${GREEN}Done! Generated ConfigMaps for all JSON dashboards.${NC}"
echo ""
echo "To apply changes:"
echo "  git add ${DASHBOARDS_DIR}/*.yaml"
echo "  git commit -m 'feat: Add dashboard ConfigMaps'"
echo "  git push"
