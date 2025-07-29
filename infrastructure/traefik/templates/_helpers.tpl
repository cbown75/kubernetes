{{/*
Expand the name of the chart.
*/}}
{{- define "traefik.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "traefik.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "traefik.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "traefik.labels" -}}
helm.sh/chart: {{ include "traefik.chart" . }}
{{ include "traefik.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "traefik.selectorLabels" -}}
app.kubernetes.io/name: {{ include "traefik.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "traefik.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "traefik.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Traefik configuration file content
*/}}
{{- define "traefik.config" -}}
global:
  checkNewVersion: false
  sendAnonymousUsage: false

api:
{{- with .Values.traefik.additionalConfiguration.api }}
{{- toYaml . | nindent 2 }}
{{- end }}

entryPoints:
{{- with .Values.traefik.additionalConfiguration.entryPoints }}
{{- toYaml . | nindent 2 }}
{{- end }}

providers:
{{- with .Values.traefik.additionalConfiguration.providers }}
{{- toYaml . | nindent 2 }}
{{- end }}

{{- if .Values.traefik.additionalConfiguration.certificatesResolvers }}
certificatesResolvers:
{{- with .Values.traefik.additionalConfiguration.certificatesResolvers }}
{{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{- if .Values.metrics.prometheus.enabled }}
metrics:
{{- with .Values.traefik.additionalConfiguration.metrics }}
{{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{- if .Values.traefik.additionalConfiguration.ping }}
ping:
{{- with .Values.traefik.additionalConfiguration.ping }}
{{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{- if .Values.logs.general.level }}
log:
  level: {{ .Values.logs.general.level }}
{{- end }}

{{- if .Values.logs.access.enabled }}
accessLog:
  format: {{ .Values.logs.access.format | default "common" }}
{{- end }}
{{- end }}
