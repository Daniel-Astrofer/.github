# Fork e prontidão para produção

Um fork funcional não é apenas copiar uma pasta: Kerosene é um polyrepo. O
fork deve conter os repositórios abaixo, na mesma revisão compatível:

`kerosene-contracts`, `kerosene-core`, `kerosene-vault`, `kerosene-node`,
`kerosene-clients`, `kerosene-deploy` e `.github`.

## Primeiro boot de um fork

1. Atualizar URLs de Git, imagens, owners e referências `Daniel-Astrofer` para
   a organização do fork.
2. Clonar os repositórios como irmãos ou usar o layout documentado pelo
   resolver de `kerosene-deploy`.
3. Executar `bash scripts/check-polyrepo-workspace.sh` no deploy e verificar
   `compatibility/kerosene.json` em cada componente.
4. Começar em `local-full`; validar build, health, migrations e smoke tests.
5. Criar secrets fora do Git. Os arquivos `*.example.yaml` são apenas o
   contrato de nomes e chaves.
6. Para staging, provisionar CA/certificados mTLS, identidade de cada Vault,
   discovery autenticado, JWT e credenciais de dados; então renderizar e
   validar o overlay.
7. Para produção, usar apenas imagens por digest, `production,hybrid`, sem
   token estático, sem `ATTESTATION_STAGING_STUB`, sem `dealer_lab` e com as
   evidências/duas aprovações exigidas pelo production gate.

## Secrets por plano

| Plano | Secrets típicos | Armazenamento permitido |
|---|---|---|
| Auth/KFE | JWT, DB, Redis, Bitcoin/LND, APIs | Secret manager operacional ou Kubernetes Secret externo |
| KFE → Mesh | certificado/PKCS#8 do cliente, CA, discovery/roster | Secret manager operacional; montagem read-only |
| Vault Mesh | certificado do nó, CA, passphrase/selagem, shares | domínio do Vault/TEE/TPM; nunca Git e nunca Auth/KFE |
| CI | tokens mínimos para leitura/publicação de artefatos | GitHub Actions secrets/OIDC; nunca shares |

## Bloqueios atuais antes do go-live

- [x] HashiCorp Vault Raft/`8200` foi removido do runtime ativo; qualquer futuro
  gerenciador de secrets deve permanecer separado da Vault Mesh.
- [ ] Ligar o KFE ao Vault Mesh no overlay de staging e provar uma operação
  completa com mTLS; o overlay atual deixa `KFE_VAULTMESH_ENABLED=false`.
- [ ] Substituir toda configuração de laboratório por secrets externos e
  discovery autenticado.
- [ ] Confirmar implementação real de TPM/TEE, attestation, PSBT e adapters que
  ainda retornam `not implemented`/stub.
- [ ] Remover ou arquivar artefatos locais de cerimônia, certificados e shares;
  fazer rotação/revogação se algum material tiver sido exposto.
- [ ] Corrigir referências históricas ao monorepo/archive e fechar a política
  de retenção do diretório `archive/`.
- [ ] Publicar releases e atualizar `compatibility/released.json` com commits
  imutáveis.

## Regra de limpeza

Só remover um arquivo quando ele for: (a) gerado e reproduzível, (b) não
rastreado por Git, (c) não for evidência necessária e (d) não contiver material
que precise de rotação ou retenção. Shares, chaves, certificados, transcripts,
logs e bases de dados devem ser tratados como material sensível e eliminados
somente com confirmação operacional e procedimento de revogação/backup.
