## 添加普通用户

为了安全，平时我们应该以普通用户的身份操作 VPS，所以需要添加一个普通用户。添加用户有两个命令，adduser 和 useradd，在不同系统中的定义以及用法上有区别，这里提供一个通用添加方法：

以添加用户名为 admin 的普通用户为例子，输入命令
```
useradd -m -s /bin/bash admin
```

然后对该用户设置密码，输入命令后会提示输入两次密码
```
passwd admin
```
## 授予普通用户 sudo 权限

有时需要使用 root 权限，比如安装软件、启动服务等操作时就需要用到 sudo 命令来提升权限才能进行操作。授予用户 sudo 权限最简单的方法是把用户添加到 sudo 用户组。

如果系统中没有 sudo，需要先安装。

#### Debian  
```
apt install sudo -y  
```
#### Centos  
```
yum install sudo -y
```
以添加 admin 这个用户到 sudo 用户组为例子，输入下面命令：
```
usermod -aG sudo admin
```
或者用以下方法：

### 修改 sudo 配置文件(etc/sudoers)

打开 sudo 配置文件
```
visudo
```
以授予 admin 这个用户 sudo 权限为例子，添加如下内容。
```
admin ALL=(ALL) ALL
```
### 添加配置文件到/etc/sudoers.d/目录中

这个是系统文档推荐的做法。/etc/sudoers.d/ 目录中的文件相当于是 etc/sudoers 文件的补充。如果你写的配置文件有问题或者是想去除用户的 sudo 权限，直接删除文件即可，不用去修改 /etc/sudoers 文件，不会影响到系统默认配置。

以授予 admin 这个用户 sudo 权限为例子，在终端中输入以下命令直接添加配置文件：
```
tee /etc/sudoers.d/admin <<< 'admin ALL=(ALL) ALL'
```
如果你不想输入每次 sudo 都输入密码，可以设置免密。
```
tee /etc/sudoers.d/admin <<< 'admin ALL=(ALL) NOPASSWD: ALL'
```
最后赋予正确的权限：
```
chmod 440 /etc/sudoers.d/admin
```
## 配置 SSH 密钥登录

使用 ssh-keygen 生成密钥对（私钥和公钥）

在本地终端中执行 ssh-keygen 命令，提示都不用管，一路回车 (Enter)

操作完后会在 ~/.ssh 目录中生两个密钥文件，id_rsa 为私钥，id_rsa.pub 为公钥。

使用 *ssh-copy-id* 配置公钥

执行以下命令自动将公钥上传并配置到 VPS 上：
```
ssh-copy-id -i ~/.ssh/id_rsa.pub User@HostName -p Port
```
-i为指定公钥路径，后面的~/.ssh/id_rsa.pub是公钥路径。

User 为用户名，HostName 为 IP 地址，Port 为端口号。

ssh-copy-id 命令相当于执行了以下复杂的手动操作：

复制公钥文件中的内容
```
cat ~/.ssh/id_rsa.pub
```
登录到远程主机
```
ssh User@HostName -p Port
```
创建 ~/.ssh 目录
```
mkdir -p ~/.ssh
```
把公钥文件写入到 ~/.ssh/authorized_keys
```
vim ~/.ssh/authorized_keys
```
设置权限
```
chmod 700 ~/.ssh  
chmod 600 ~/.ssh/authorized_keys
```
所以使用 ssh-copy-id 大大简化了 SSH 密钥的配置过程。

## 禁用不安全的登录方式

前面的一系列操作都是铺垫，是为禁止 root 账户登录和密码登录以及修改 SSH 端口做准备，这才是提升 VPS 安全性的主要目的。

打开 sshd 配置文件 (/etc/ssh/sshd_config) 进行修改。
```
sudo nano /etc/ssh/sshd_config
```
### 禁止密码登录

找到 PasswordAuthentication，一般情况看到的应该是这样的：
```
#PasswordAuthentication yes
```
去掉前面的#，把 yes 改为 no，像下面这样：
```
PasswordAuthentication no
```
### 禁止 root 登录

找到 PermitRootLogin，对默认使用 root 登录的 VPS ，看到的应该是这样的：
```
PermitRootLogin yes
```
要完全禁止 root 登录，把 yes 改为 no，像下面这样：
```
PermitRootLogin no
```
### 修改 SSH 端口

找到 Port，默认情况下这个选项是被注释，像下面这样：
```
#Port 22
```
去掉前面的#，把后面的 22 换成其它端口，比如 2222，像下面这样：
```
Port 2222
```
### 重启 sshd 服务

为了使以上修改生效，需要重启 sshd 服务
```
sudo service sshd restart
```
### 清除 root 用户密码

当清除 root 用户密码后，就无法使用 su 命令切换到 root 用户。只有被授予 sudo 权限的用户执行 sudo -i 命令并输入当前用户的密码才能切换到 root 用户，进一步提升了安全性。
```
sudo passwd -d root
```
## 删除用户

以删除 admin 这个用户为例子，首先终结该用户所有进程
```
pkill -u admin
```
然后输入删除命令
```
userdel -r admin
```
-r 表示删除用户的同时，将其宿主目录和系统内与其相关的内容删除。

## 配置ssh密钥一键脚本：  
```
bash <(curl -fsSL bit.ly/key-sh) -og ceigt -p 2222 -d
```

## 通过acme.sh申请ECC证书：
```  
curl https://get.acme.sh | sh  
. .bashrc  
acme.sh --upgrade --auto-upgrade  
acme.sh --set-default-ca --server letsencrypt  
export CF_Key="xxxxxxxxxx"  
export CF_Email="you@email.com"  
acme.sh --issue --dns dns_cf -d www.example.com --keylength ec-256 --force  
acme.sh --install-cert -d www.example.com --ecc  --fullchain-file ~/certs/example.crt  --key-file ~/certs/example.key 
```