# Shark-infra

# シークレットの注入について

[argocd-vault-plugin](https://argocd-vault-plugin.readthedocs.io/en/stable/) によってシークレットが注入されます。シークレット取得には下記の用な記述を使用します

```yaml
kind: Secret
apiVersion: v1
metadata:
  name: hoge
  annotations:
    avp.kubernetes.io/path: "secret/hoge/hoge"
type: Opaque
data:
  username: <username>
  password: <password>
```

取得元は本リポジトリでは管理しません