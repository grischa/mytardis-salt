nfs-common:
  pkg.installed: []

{% for mount_point, args in salt['pillar.get']('nfs-servers').items() %}
{{ mount_point }}:
  mount.mounted:
    - device: "localhost:{{ args['mount_path'] }}"
        # {% for host in salt['mine.get']('G@roles:' + args['server_role'] + ' and G@deployment:' + salt['grains.get']('deployment', 'test'), 'network.ip_addrs', 'compound').items() %}{{ host.1[0] }}:{{ args['mount_path'] }}{% endfor %}
    - fstype: nfs
    - mkmnt: True
    - opts: {{ args['mount_options'] }}
    - persist: True
    - mount: False
{% if 'nfs-client' in salt['pillar.get']('roles') and grains['os_family'] != 'RedHat' %}
    - require:
        - pkg: nfs-common
        - service: stunnel4-service-for-nfs
{% endif %}

timeout-mount-{{ mount_point }}:
  cmd.run:
    - name: 'mount {{ mount_point }} & sleep 30; killall -9 mount.nfs'
    - unless: 'mount | grep {{ mount_point }}'
    - require:
        - mount: {{ mount_point }}
{% endfor %}
