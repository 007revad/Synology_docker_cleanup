# Synology docker cleanup

<a href="https://github.com/007revad/Synology_docker_cleanup/releases"><img src="https://img.shields.io/github/release/007revad/Synology_docker_cleanup.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2F007revad%2FSynology_docker_cleanup&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=views&edge_flat=false"/></a>
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/paypalme/007revad)
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/007revad)
[![committers.top badge](https://user-badge.committers.top/australia/007revad.svg)](https://user-badge.committers.top/australia/007revad)

### Description

Remove orphan docker btrfs subvolumes and images in Synology DSM 7 and DSM 6

### After running the script

If any containers get stuck while updating just stop then start Container Manager.
<p align="left"><img src="/images/updating.png"></p>

If have any duplicate containers whose name ends in .syno.bak.
<p align="left"><img src="/images/syno.bak.png"></p>

### Screenshots

<p align="center">Deleting orphan docker subvolumes</p>
<p align="center"><img src="/images/delete_orphans.png"></p>

<br>

<p align="center">No more orphan docker subvolumes</p>
<p align="center"><img src="/images/no_orphans.png"></p>

<br>

