#!/usr/bin/env bash
set -euo pipefail

# ======= Parámetros =======
REGION="${REGION:-us-east-1}"
SECRET_NAME="${SECRET_NAME:-rsa-keys/dev}"   # ej: "rsa-keys/dev" o "rsa-keys/prod"
OUT_DIR="${OUT_DIR:-./keys}"                  # carpeta de salida local

# ======= Preparación =======
mkdir -p "${OUT_DIR}"

PRIV_PEM="${OUT_DIR}/rsa_private.pem"
PUB_PEM="${OUT_DIR}/rsa_public.pem"
PRIV_B64="${OUT_DIR}/rsa_private.pem.b64"
PUB_B64="${OUT_DIR}/rsa_public.pem.b64"

echo "===> Generando llaves RSA (2048) en ${OUT_DIR}"
# Private key PKCS#1
openssl genrsa -out "${PRIV_PEM}" 2048
# Public key
openssl rsa -in "${PRIV_PEM}" -pubout -out "${PUB_PEM}"

echo "===> Convirtiendo a base64 de una sola línea"
# Linux (GNU coreutils). En macOS usar: base64 < file | tr -d '\n' > file.b64
if base64 --help 2>&1 | grep -q -- '-w'; then
  base64 -w0 "${PRIV_PEM}" > "${PRIV_B64}"
  base64 -w0 "${PUB_PEM}"  > "${PUB_B64}"
else
  base64 < "${PRIV_PEM}" | tr -d '\n' > "${PRIV_B64}"
  base64 < "${PUB_PEM}"  | tr -d '\n' > "${PUB_B64}"
fi

PRIV_B64_STR="$(cat "${PRIV_B64}")"
PUB_B64_STR="$(cat "${PUB_B64}")"

SECRET_JSON="$(jq -n --arg pub "${PUB_B64_STR}" --arg priv "${PRIV_B64_STR}" \
  '{public_key_b64:$pub, private_key_b64:$priv}')"

echo "===> Creando/actualizando secreto '${SECRET_NAME}' en ${REGION}"
set +e
aws secretsmanager describe-secret --region "${REGION}" --secret-id "${SECRET_NAME}" >/dev/null 2>&1
EXISTS=$?
set -e

if [ "${EXISTS}" -eq 0 ]; then
  aws secretsmanager put-secret-value \
    --region "${REGION}" \
    --secret-id "${SECRET_NAME}" \
    --secret-string "${SECRET_JSON}" >/dev/null
  echo "Secreto actualizado: ${SECRET_NAME}"
else
  aws secretsmanager create-secret \
    --region "${REGION}" \
    --name "${SECRET_NAME}" \
    --description "RSA PEM keys (base64)" \
    --secret-string "${SECRET_JSON}" >/dev/null
  echo "Secreto creado: ${SECRET_NAME}"
fi

echo "===> Listo:"
echo "  - Privada: ${PRIV_PEM}"
echo "  - Pública: ${PUB_PEM}"
echo "  - Secreto: ${SECRET_NAME} (region: ${REGION})"
