mytardis_db_user:
  postgres_user.present:
    - name: {{ pillar['mytardis_db_user'] }}
    - password: {{ pillar['mytardis_db_pass'] }}
{% if not ( 'postgres-server' in salt['grains.get']('roles') or
            'postgres-server' in salt['pillar.get']('roles') ) %}
    - require:
        - pkg: postgresql-client
{% endif %}

mytardis_db:
  postgres_database.present:
    - name: {{ pillar['mytardis_db'] }}
    - owner: {{ pillar['mytardis_db_user'] }}
    - require:
        - postgres_user: {{ pillar['mytardis_db_user'] }}

