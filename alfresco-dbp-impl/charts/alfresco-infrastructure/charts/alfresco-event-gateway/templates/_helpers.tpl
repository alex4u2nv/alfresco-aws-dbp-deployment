
{{/* vim: set filetype=mustache: */}}

{{/*
Create a default fully qualified backend name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "alfresco-event-gateway.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s-backend" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
