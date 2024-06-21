#### PVE 显卡直通设定：
```
nano /etc/default/grub
```
```
  GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
```
```
update-grub
```
```
nano /etc/modules
```
```
  vfio  
  vfio_iommu_type1  
  vfio_pci  
  vfio_virqfd  
```
```
update-initramfs -u -k all   
reboot
```
把两个rom file copy到 */use/share/kvm/*

机型必须i440fx，BIOS必须OVMF，优化：开启agent，使用localtime，cpu numa  
```
args: -set device.hostpci0.addr=02.0 -set device.hostpci0.x-igd-gms=0x2 -set device.hostpci0.x-igd-opregion=on  
legacy-igd=1  
```
具体设置参数可参考以下：
```
agent: 1
args: -set device.hostpci0.addr=02.0 -set device.hostpci0.x-igd-gms=0x2 -set device.hostpci0.x-igd-opregion=on
bios: ovmf
boot: order=scsi0;net0
cores: 4
cpu: host
efidisk0: local-lvm:vm-101-disk-0,efitype=4m,pre-enrolled-keys=1,size=4M
hookscript: local:snippets/hooks-igpupt.pl
hostpci0: 0000:00:02.0,legacy-igd=1,romfile=gen12_igd.rom
hostpci1: 0000:00:1f.3,romfile=IntelGopDriver.rom
hostpci2: 0000:00:14.3
localtime: 1
machine: pc-i440fx-8.0
memory: 8192
meta: creation-qemu=8.0.2,ctime=1694798637
name: Win10
net0: virtio=hw:addr,bridge=vmbr0,firewall=1
numa: 1
onboot: 1
ostype: win10
scsi0: local-lvm:vm-101-disk-1,iothread=1,size=100G,ssd=1
scsihw: virtio-scsi-single
smbios1: uuid=7f0ae1cc-64e2-4313-9963-0434db48afe8
sockets: 1
startup: order=4
tags:  
usb0: host=1-1,usb3=1
usb1: host=1-2,usb3=1
usb2: host=8087:0026,usb3=1
vga: none
vmgenid: 4e6d2689-527a-48eb-a89b-35be497e6e58
```
#### PVE下KVM虚拟机直通钩子脚本
```
git clone https://github.com/ceigt/pvevm-hooks.git
```
添加可执行权限
```
cd pvevm-hooks    
chmod a+x *.sh *.pl
```
脚本中默认没有启用USB直通返回，如需启用，请取消vm-stop.sh中“echo $usb_addr...”两行注释。
复制perl脚本至snippets目录
```
mkdir /var/lib/vz/snippets  
cp hooks-igpupt.pl /var/lib/vz/snippets/hooks-igpupt.pl
```
将钩子脚本应用至虚拟机
```
qm set <VMID> --hookscript local:snippets/hooks-igpupt.pl
```
#### 安装PNET  
```
tar -xvf PNET_4.2.10.ova  
qm importovf 103 PNET_4.2.10.ovf local-lvm 
```

#### 安装openwrt  
```
qm disk import 100 /var/lib/vz/template/iso/xxx.img local-lvm
```

#### lxc特权容器  
```
nano /etc/pve/lxc/100.conf
```
```
  lxc.cgroup2.devices.allow: c 226:0 rwm  
  lxc.cgroup2.devices.allow: c 226:128 rwm  
  lxc.cgroup2.devices.allow: c 29:0 rwm  
  lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir  
  lxc.mount.entry: /dev/fb0 dev/fb0 none bind,optional,create=file  
  lxc.apparmor.profile: unconfined  
```

#### linux中通过smb挂载远程文件夹
```
apt install cifs-utils -y  
mkdir /mnt/nas
```
```
nano ~/.smbcredentials
```
```
  username=admin  
  password=xxxxx
```
```
nano /etc/fstab
```
```
//10.0.0.6/share /mnt/nas cifs credentials=/root/.smbcredentials,iocharset=utf8 0 0
```
or without passwdfile:  
```
//10.0.0.6/shared /mnt/nas cifs username=admin,password=xxxxx,iocharset=utf8 0 0
```

#### 安装docker  
```
curl -fsSL https://get.docker.com -o get-docker.sh  
sudo sh get-docker.sh
```

#### 【portainer】 
```   
docker volume create portainer_data
```
```
docker run -d -p 8000:8000 -p 9000:9000 --name portainer \  
    --restart=always \  
    -v /var/run/docker.sock:/var/run/docker.sock \  
    -v portainer_data:/data \  
    portainer/portainer-ce
```
```
docker run -d -p 9443:9443 -p 8000:8000 \  
    --name portainer --restart always \  
    -v /var/run/docker.sock:/var/run/docker.sock \  
    -v portainer_data:/data \  
    -v /home/user/certs:/certs \  
    portainer/portainer-ce:latest \  
    --sslcert /certs/xxx.crt \  
    --sslkey /certs/xxx.key   
```

#### 【aria2】  
```
docker run -d \  
    --name aria2 \  
    --restart unless-stopped \  
    --network host \  
    --log-opt max-size=1m \  
    -e PUID=$UID \  
    -e PGID=$GID \  
    -e RPC_SECRET=passwd \  
    -e SPECIAL_MODE=move \  
    -v /usr/local/bin/aria2/config:/config \  
    -v /mnt/nas/downloads:/downloads \  
    -v /mnt/nas/media:/completed \  
    p3terx/aria2-pro  
```
```
docker run -d \  
    --name aria2 \  
    --restart unless-stopped \  
    --network host \  
    --log-opt max-size=1m \  
    -e PUID=0 \  
    -e PGID=0 \  
    -e RPC_SECRET=password \  
    -e SPECIAL_MODE=move \  
    -v /home/user/aria2/config:/config \  
    -v /home/user/aria2/downloads:/downloads \  
    -v /home/user/jellyfin/media/tv:/completed/tv \  
    -v /home/user/jellyfin/media/movie:/completed/movie \  
    p3terx/aria2-pro
```
```
nano /usr/local/bin/aria2/config/script.conf
```
```
  dest_dir = /completed
```

#### 【jellyfin】  
```
docker run -d \  
 --name jellyfin \  
 --net=host \  
 --device /dev/dri:/dev/dri \  
 --volume /home/user/jellyfin/config:/config \  
 --volume /home/user/jellyfin/cache:/cache \  
 --mount type=bind,source=/home/user/jellyfin/media,target=/media \  
 --restart=unless-stopped \  
 jellyfin/jellyfin
```

#### 【qinglong】  
```
docker run -dit \  
  -v $PWD/ql:/ql/data \  
  -p 5700:5700 \  
  --name qinglong \  
  --hostname qinglong \  
  --restart unless-stopped \  
  whyour/qinglong:latest  
```
docker compose
```
version: "3"  
services:  
  qinglong:  
    image: whyour/qinglong:latest  
    container_name: qinglong  
    restart: unless-stopped  
    tty: true  
    ports:  
      - 5700:5700  
      - 5701:5701  
    environment:  
      - ENABLE_HANGUP=true  
      - ENABLE_WEB_PANEL=true  
    volumes:  
      - ./config:/ql/data/config  
      - ./log:/ql/data/log  
      - ./db:/ql/data/db  
      - ./repo:/ql/data/repo  
      - ./raw:/ql/data/raw  
      - ./scripts:/ql/data/scripts  
      - ./jbot:/ql/data/jbot  
      - ./ninja:/ql/data/ninja  
    labels:  
      - com.centurylinklabs.watchtower.enable=false  
``` 

#### openwrt抓包  
```
opkg update  
opkg install tcpdump  
```
在windows系统plink文件夹打开cmd执行以下命令 
``` 
.\plink.exe -batch -ssh -pw Oppasswd root@10.0.0.1 "tcpdump -ni br-lan -s 0 -w - not port 22" | "C:\Program Files\Wireshark\Wireshark.exe" -k -i -
```  




















