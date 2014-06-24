{% set sec_nfs_port = "12049" %}
{% set nfs_port = "2049" %}
{% if salt['pillar.get']('nfs_stunnel', False) %}
# install stunnel to secure nfs connections
stunnel-pkg-for-nfs:
  pkg.installed:
    - name: {{ pillar['stunnel_pkg'] }}

{% if grains['os_family'] != 'RedHat' %}
stunnel-settings-for-nfs:
  file.replace:
    - name: /etc/default/stunnel4
    - pattern: 'ENABLED=0'
    - repl: 'ENABLED=1'
    - backup: ''
    - require:
        - pkg: stunnel-pkg-for-nfs
{% endif %}

# create certificates for stunnel
/etc/stunnel/nfs.conf:
  file.managed:
    - source: salt://templates/stunnel-nfs-client-conf
    - template: jinja
    - context:
        nfs_port: "{{ nfs_port }}"
        sec_nfs_port: "{{ sec_nfs_port }}"
        nfs_servers:
{% for host in salt['mine.get']('G@roles:nfs-server and G@deployment:' + salt['grains.get']('deployment', 'test'),
                                'network.ip_addrs', 'compound').items() %}
          - {{ host.1 }}
{% endfor %}
    - require:
        - pkg: stunnel-pkg-for-nfs

{% if grains['os_family'] != 'RedHat' %}
stunnel4-service-for-nfs:
  service.running:
    - name: stunnel4
    - enable: True
    - sig: stunnel4
    - watch:
        - file: /etc/stunnel/nfs.conf
    - require:
        - file: stunnel-settings-for-nfs
{% endif %}
{% endif %} # stunnel for redis
