#!/bin/bash

# cloudflareのIPアドレス変更を検知&githubActionsにてプルリクを作成

CLOUDFLARE_V4_LIST=https://www.cloudflare.com/ips-v4
CLOUDFLARE_V6_LIST=https://www.cloudflare.com/ips-v6

V4_IPS=$(curl $CLOUDFLARE_V4_LIST | base64)
V6_IPS=$(curl $CLOUDFLARE_V6_LIST | base64)

LOCAL_V4_IPS=$(cat cf_ipv4.txt | base64)
LOCAL_V6_IPS=$(cat cf_ipv6.txt | base64)

if [ "$V4_IPS" = "$LOCAL_V4_IPS" ]; then
  echo "V4アドレスはローカルの内容と変更されていません"
else
  rm -f cf_ipv4.txt
  echo "$V4_IPS" | base64 -d >> cf_ipv4.txt
  echo "V4アドレスの変更内容を反映しました"
fi

if [ "$V6_IPS" = "$LOCAL_V6_IPS" ]; then
  echo "V6アドレスはローカルの内容と変更されていません"
else
  rm -f cf_ipv6.txt
  echo "$V6_IPS" | base64 -d >> cf_ipv6.txt
  echo "V6アドレスの変更内容を反映しました"
fi