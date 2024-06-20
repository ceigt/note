#### 生成密钥对

默认生成 2048 位 RSA 密钥
```
ssh-keygen
```
生成 4096 位 RSA 密钥
```
ssh-keygen -t rsa -b 4096
```
生成 521 位 ECDSA 密钥
```
ssh-keygen -t ecdsa -b 521
```
私钥生成公钥
```
ssh-keygen -y -f [private-key-path] > [output-path]
```
比如，有一个文件名为 id_rsa 私钥，想用它生成 id_rsa.pub 公钥
```
ssh-keygen -y -f id_rsa > id_rsa.pub
```
选项说明

> +  -t 指定生成密钥的类型，默认 RSA

> +  -f 指定生成密钥的路径，默认 ~/.ssh/id_rsa（私钥 id_rsa，公钥 id_rsa.pub）

> +  -P 提供旧密码，空表示不需要密码（-P ''）

> +  -N 提供新密码，空表示不需要密码 (-N '')

> +  -b 指定密钥长度（bits），默认是 2048 位

> +  -C 提供一个新注释，比如邮箱

> +  -y 读取 OpenSSH 格式私钥文件并将 OpenSSH 公钥输出到 std­out

> +  -q 安静模式
