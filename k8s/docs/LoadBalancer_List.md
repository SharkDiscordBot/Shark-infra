# 使用中IP

192.168.50.1-192.168.52.254の範囲でLoadBalancerのIP範囲を設定しています。手動で割り当てているIPは下記のとおりです

| Target_app | Address | note |
| ---- | ---- | ------ |
| argocd-server | 192.168.51.1 | Cloudflare障害時にもローカル環境からアクセスできるように |