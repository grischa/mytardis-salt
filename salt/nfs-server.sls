{% set nfs_port = 2049 %}
{% set sec_nfs_port = 12049 %}

nfs-kernel-server:
  pkg.installed: []

restart-nfs:
  module.wait:
    - name: service.restart
    - m_name: nfs-kernel-server
    - watch:
        - file: /etc/exports
    - require:
        - pkg: nfs-kernel-server

/etc/exports:
  file.append:
    - text: "/foo localhost"
    - require:
        - pkg: nfs-kernel-server

# /srv/public_data_volume:
#   mount.mounted:
#     - device: /dev/vdc
#     - fstype: zfs
#     - mkmnt: True
#     - opts:
#         - defaults
#     - require:
#         - pkg: ubuntu-zfs

zfs-native:
  pkgrepo.managed:
    - ppa: zfs-native/stable

ubuntu-zfs:
  pkg.installed:
    - require:
        - pkgrepo: zfs-native


{% if salt['pillar.get']('nfs_stunnel', False) %}
# install stunnel
stunnel:
  pkg.installed:
    - name: stunnel4

python-openssl-restart:
  service.restart:
    - name: salt-minion
    - require:
        - pkg: python-openssl

python-openssl:
  pkg.installed: []

/etc/default/stunnel4:
  file.replace:
    - pattern: 'ENABLED=0'
    - repl: 'ENABLED=1'
    - backup: ''
    - require:
        - pkg: stunnel

# create certificates for stunnel
{% set nfs_stunnel_ca_name = salt['pillar.get']('nfs_stunnel_ca_name', 'nfs_stunnel_ca') %}
{% set cert_path = '/etc/pki/'~nfs_stunnel_ca_name~'/'~nfs_stunnel_ca_name~'_ca_cert' %}
tls.create_ca:
  module.run:
    - ca_name: '{{ nfs_stunnel_ca_name }}'
    - CN: '{{ grains['host'] }}'
    - C: 'AU'
    - ST: 'Victoria'
    - L: 'Melbourne'
    - O: 'MyTardis'
    - emailAddress: '{{ salt['pillar.get']('admin_email_address', 'admin@localhost') }}'
    - require:
        - pkg: python-openssl

tls.create_csr:
  module.run:
    - ca_name: '{{nfs_stunnel_ca_name}}'
    - CN: '{{ grains['host'] }}'
    - C: 'AU'
    - ST: 'Victoria'
    - L: 'Melbourne'
    - O: 'MyTardis'
    - emailAddress: '{{ salt['pillar.get']('admin_email_address', 'admin@localhost') }}'
    - require:
        - module: tls.create_ca

tls.create_ca_signed_cert:
  module.run:
    - ca_name: '{{ nfs_stunnel_ca_name }}'
    - CN: '{{ grains['host'] }}'
    - require:
        - module: tls.create_csr
# end create certs

/etc/stunnel/nfs.conf:
  file.managed:
    - source: salt://templates/stunnel-nfs-conf
    - template: jinja
    - context:
        nfs_port: '{{ nfs_port }}'
        sec_nfs_port: '{{ sec_nfs_port }}'
        cert_path: '{{ cert_path }}'
    - require:
        - pkg: stunnel

stunnel4:
  service.running:
    - require:
        - file: /etc/stunnel/nfs.conf
        - module: tls.create_ca_signed_cert
{% endif %} # stunnel


{% for name, mount_point in salt['pillar.get']('nfs-exports', []).items() %}
{% if salt['pillar.get']('nfs_stunnel', False) %}
zfs set sharenfs="rw=@localhost,insecure" {{ name }}:
{% else %}
zfs set sharenfs="rw@*" {{ name }}:
{% endif %}
  cmd.run:
    - require:
        - cmd: zpool-create
        - pkg: ubuntu-zfs
        - module: restart-nfs

zfs set mountpoint={{ mount_point }} {{ name }}:
  cmd.run:
    - require:
        - cmd: zpool-create
        - pkg: ubuntu-zfs

zpool import -fa:
  cmd.run:
    - require:
        - pkg: ubuntu-zfs

zpool-create:
  cmd.run:
    - name: zpool create {{ name }} /dev/vdc
    - unless: zpool list|grep static_files
    - require:
        - cmd: "zpool import -fa"
        - cmd: partition-volume

partition-volume:
  cmd.run:
    - name: parted -s /dev/vdc mklabel gpt
    - unless: "parted -lm /dev/vdc|grep /dev/vdc|grep gpt"
{% endfor %}
