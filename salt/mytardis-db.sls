{% set deployment = salt['grains.get']('deployment') %}
db_user:
  postgres_user.present:
    - name: {{ pillar['mytardis_db_user'] }}
    - password: {{ pillar['mytardis_db_pass'] }}
{% if 'postgres-server' not in salt['grains.get']('roles', []) %}
    - db_host: {{ salt['mine.get']('G@roles:postgres-server and G@deployment:' + deployment, 'network.ip_addrs', expr_form='compound').items()[0][1][0] }}
    - db_user: {{ pillar['mytardis_db_user'] }}
    - db_password: '{{ pillar['mytardis_db_pass'] }}'
{% endif %}
{% if not ( 'postgres-server' in salt['grains.get']('roles') or
            'postgres-server' in salt['pillar.get']('roles') ) %}
    - require:
        - pkg: postgresql-client
{% else %}
    - require:
        - pkg: postgresql-server
{% endif %}

database:
  postgres_database.present:
    - name: {{ pillar['mytardis_db'] }}
    - owner: {{ pillar['mytardis_db_user'] }}
{% if 'postgres-server' not in salt['grains.get']('roles', []) %}
    - db_host: {{ salt['mine.get']('G@roles:postgres-server and G@deployment:' + deployment, 'network.ip_addrs', expr_form='compound').items()[0][1][0] }}
    - db_user: {{ pillar['mytardis_db_user'] }}
    - db_password: '{{ pillar['mytardis_db_pass'] }}'
{% endif %}
    - require:
        - postgres_user: {{ pillar['mytardis_db_user'] }}
