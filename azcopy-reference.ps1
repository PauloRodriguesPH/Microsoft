#########################################
# GUIA DE REFERÊNCIA DE COMANDOS AZCOPY #
#########################################

<#
# Autor: Paulo Henrique da Silva Motta Rodrigues
# Testado em: Windows Server 2016 com AzCopy
# Data do teste: 06/01/2026
# Uso: este arquivo é um catálogo; copie e rode os comandos conforme necessidade.
#>

# ============================================================
# SINCRONIZAÇÃO (SIMULAÇÃO)
# Mostra o que seria sincronizado entre origem e destino, sem copiar absolutamente nada.
# Ideal para validação antes de rodar de verdade, ou validar uma cópia realizada.
azcopy sync "D:\CAMINHO\ORIGEM\*" "https://<storage-account>.blob.core.windows.net/<container>/<path>?<SAS_TOKEN>" --recursive --dry-run

# ============================================================
# CÓPIA SIMPLES PARA AZURE BLOB (ARCHIVE TIER)
# Copia todos os arquivos da origem para o destino, gravando diretamente no tier Archive.
azcopy copy "D:\CAMINHO\ORIGEM\*" "https://<storage-account>.blob.core.windows.net/<container>/<path>?<SAS_TOKEN>" --recursive=true --block-blob-tier=Archive

# ============================================================
# LISTAR TODOS OS JOBS DO AZCOPY
# Mostra o histórico de execuções realizadas. Útil para identificar JobID.
azcopy jobs list

# ============================================================
# MOSTRAR ERROS DE UM JOB ESPECÍFICO
# Usa o JobID obtido no comando jobs list.
azcopy jobs show <JobID> --with-status=Failed

# ============================================================
# MOSTRAR DETALHES COMPLETOS DE UM JOB
# Exibe todos os arquivos processados,  incluindo sucesso, falha e estatísticas.
azcopy jobs show <JobID>

# ============================================================
# RETOMAR APENAS ARQUIVOS QUE FALHARAM
# Reexecuta somente o que deu erro, sem copiar novamente o que já deu certo.
# Ideal para corrigir falhas pontuais sem precisar refazer toda a cópia ou sincronização do zero.
azcopy jobs resume <JobID>