{{- /*
Common helper template for FluxCD chart
*/ -}}

{{- define "fluxcd.name" -}}
flux
{{- end -}}

{{- define "fluxcd.chart" -}}
{{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{- define "fluxcd.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if .Values.nameOverride }}
{{- .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "fluxcd.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end -}}

{{- define "fluxcd.labels" -}}
helm.sh/chart: {{ include "fluxcd.chart" . | quote }}
app.kubernetes.io/name: {{ include "fluxcd.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end -}}

{{- define "fluxcd.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fluxcd.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
