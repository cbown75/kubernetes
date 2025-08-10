{{- define "nfs-csi-driver.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "nfs-csi-driver.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "nfs-csi-driver.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "nfs-csi-driver.labels" -}}
helm.sh/chart: {{ include "nfs-csi-driver.chart" . }}
{{ include "nfs-csi-driver.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "nfs-csi-driver.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nfs-csi-driver.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "nfs-csi-driver.controllerServiceAccountName" -}}
{{- printf "%s-controller-sa" (include "nfs-csi-driver.fullname" .) }}
{{- end }}

{{- define "nfs-csi-driver.nodeServiceAccountName" -}}
{{- printf "%s-node-sa" (include "nfs-csi-driver.fullname" .) }}
{{- end }}
