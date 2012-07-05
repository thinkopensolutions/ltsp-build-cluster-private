#!/bin/bash

echo "0. Criar imagem inicial dos clientes..."
echo -n "(ctrl+c to interrupt, enter to continue)"
read ok
sudo ltsp-build-client --accept-unsigned-packages --skipimage || exit

echo "1. Copiar o tema PRIME para o chroot..."
echo -n "(ctrl+c to interrupt, enter to continue)"
read ok
sudo cp -r default_files/prime_theme /opt/ltsp/i386/usr/share/ldm/themes/ &&
cd /opt/ltsp/i386/usr/share/ldm/themes/ && sudo ln -sf prime_theme default &&
cd - || exit

echo "2. Instalar NFS para as eventuais aplicações locais poderem aceder a pastas no servidor..."
echo -n "(ctrl+c to interrupt, enter to continue)"
read ok
sudo chroot /opt/ltsp/i386 apt-get install nfs-common &&
sudo apt-get install nfs-kernel-server &&
sudo cp default_files/nfsmounts.sh /opt/ltsp/i386/etc/nfsmounts.sh || exit
echo "   - Modifique o ficheiro /etc/default/nfs-common (tanto no cliente como no servidor): colocar o NEED_IDMAPD= yes."
sudo gedit /etc/default/nfs-common /opt/ltsp/i386/etc/default/nfs-common
sudo /etc/init.d/idmapd restart
echo "   - Modifique o ficheiro /etc/exports. Adicionar os pontos que quer fazer visíveis localmente."
echo "     (ex: /home 172.31.100.0/24(rw,no_root_squash,async,no_subtree_check)"
sudo gedit /etc/exports
exportfs -ra

echo "3. Aumentar o tamanho da swap dos clientes..."
echo -n "(ctrl+c to interrupt, enter to continue)"
echo "   - Edite o ficheiro /etc/ltsp/nbdswapd.conf e coloque uma linha com \"SIZE=128\", tamanho em Mb."
sudo gedit /etc/ltsp/nbdswapd.conf
read ok

echo "4. Instalar as aplicações que irão correr localmente..."
echo -n "(ctrl+c to interrupt, enter to continue)"
read ok
sudo cp /etc/apt/sources.list /opt/ltsp/i386/etc/apt/ &&
sudo chroot /opt/ltsp/i386 apt-key  adv --keyserver keyserver.ubuntu.com --recv-keys A3436E8D &&
sudo chroot /opt/ltsp/i386 apt-key  adv --keyserver keyserver.ubuntu.com --recv-keys 3E5C1192 &&
sudo chroot /opt/ltsp/i386 apt-get update &&
sudo chroot /opt/ltsp/i386 apt-get install firefox-locale-pt firefox-globalmenu language-pack-gnome-pt language-pack-gnome-pt-base language-support-pt language-support-writing-pt libreoffice libreoffice-help-pt libreoffice-help-pt-br libreoffice-l10n-common libreoffice-l10n-pt libreoffice-l10n-pt-br maint-guide-pt-br manpages-pt manpages-pt-dev sun-java6-plugin flashplugin-nonfree chromium-browser gimp blender totem banshee pitivi openshot audacity hydrogen muse nted playitslowly tuxguitar songwrite videoporama salasaga geogebra unity language-pack-gnome-pt language-pack-gnome-pt-base language-support-pt language-support-writing-pt libreoffice libreoffice-help-pt libreoffice-help-pt-br libreoffice-l10n-common libreoffice-l10n-pt libreoffice-l10n-pt-br maint-guide-pt-br manpages-pt apturl evince manpages-pt-dev nautilus nautilus-sendto-empathy nautilus-sendto || exit
#
# IN LTSP CLUSTER
# -----------------------------------------------------------------------------
# apt-get install firefox openoffice.org-l10n-pt openoffice.org-help-pt gcompris-sound-pt language-pack-gnome-pt language-pack-gnome-pt-base language-pack-pt language-pack-pt-base openoffice.org-hyphenation-pt language-support-pt chromium-browser gimp blender totem banshee pitivi openshot audacity hydrogen muse nted tuxguitar songwrite salasaga geogebra evince

echo "   - Se houve algum erro deve fazer chroot e instalar lá de dentro."
echo "   - Colocar o tamanho da página de impressão por omissão para A4."
echo "     (ex: editar ficheiros /etc/firefox/syspref.js e /etc/papersize"
echo "      o primeiro já foi copiado dos defaults e no segundo deve estar \"a4\")"
sudo cp default_files/syspref.js /etc/firefox/syspref.js || exit
sudo gedit /etc/papersize /etc/firefox/syspref.js

echo "5. Configuração do CUPS, para os clientes poderem imprimir..."
echo -n "(ctrl+c to interrupt, enter to continue)"
read ok
sudo chroot /opt/ltsp/i386 apt-get install cups-bsd &&
sudo cp default_files/cupsd.conf /etc/cups/ &&
sudo gedit /etc/cups/cupsd.conf
sudo /etc/init.d/cups restart

echo "6. Modificar o script /usr/bin/libreoffice, para correr o Libreoffice localmente..."
echo -n "(ctrl+c to interrupt, enter to continue)"
read ok
echo "   - Colocar ltsp-localapps no início da linha que corre o soffice.biqn."
echo "     (ex: ltsp-localapps /usr/lib/libreoffice/program/soffice  \"\$\@\")"
sudo gedit /usr/bin/libreoffice

echo "7. Instalar iTALC para controlo da sala de aula..."
echo -n "(ctrl+c to interrupt, enter to continue)"
sudo chroot /opt/ltsp/i386 apt-get --install italc-master italc-client &&
sudo apt-get install italc-master &&
sudo cp -r /opt/ltsp/i386/etc/italc/keys /etc/keys &&
sudo chgrp professores /etc/italc/keys/private/teacher/key &&
sudo chgrp admin /etc/italc/keys/private/supporter/key &&
sudo chgrp admin /etc/italc/keys/private/admin/key || exit
ls -l /etc/italc/keys/private/teacher/

echo "8. Instalar Mimio Interactive..."
echo -n "(ctrl+c to interrupt, enter to continue)"
read ok
sudo cp default_files/mimio-studio_8.0-4intl_i386.deb /opt/ltsp/i386/root/ &&
sudo chroot /opt/ltsp/i386 dpkg --install /root/mimio-studio_8.0-4intl_i386.deb &&
sudo chroot /opt/ltsp/i386 apt-get -f install || exit
echo "   - Se houve algum erro deve fazer chroot e instalar lá de dentro."
echo "     (tentar instalar e ser der erro de dependências fazer logo de seguinda apt-get -f install)"

echo "9. Actualizar a imagem dos cliente..."
echo "   - Comprimir a imagem, para isso comente a linha NO_COMP do"
echo "     ficheiro /etc/ltsp/ltsp-update-image.conf."
echo "     (ex: #NO_COMP=\"-noF -noD -noI -no-exports\")"
echo -n "(ctrl+c to interrupt, enter to continue)"
read ok
sudo gedit /etc/ltsp/ltsp-update-image.conf
sudo ltsp-update-image

echo DONE
echo -n "(ctrl+c to interrupt, enter to continue)"
read ok

