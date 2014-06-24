{% if grains['os_family'] == "RedHat" %}
pgsql-repo:
  pkg.installed:
    - sources:
{% if grains['os'] == "CentOS" %}
      - pgdg-centos93: "http://yum.postgresql.org/9.3/redhat/rhel-6-x86_64/pgdg-centos93-9.3-1.noarch.rpm"
{% else %}
      - pgdg-redhat93: "http://yum.postgresql.org/9.3/redhat/rhel-6-x86_64/pgdg-redhat93-9.3-1.noarch.rpm"
{% endif %}
    - require_in:
      - pkg: postgresql-server
{% endif %}

/etc/postgresql/9.3/main/postgresql.conf:
  file.append:
    - text: "listen_addresses = '*'"
    - require:
        - pkg: postgresql
    - require_in:
        - service: postgresql-server


postgresql-server:
  pkg.installed:
    - names:
    {% if grains['os_family'] == "RedHat" %}
      - postgresql93-server
    {% elif grains['os_family'] == 'Debian' %}
      - postgresql
    {% endif %}

{% if grains['os_family'] == 'Debian' %}
  file.append:
    - name: /etc/postgresql/9.3/main/pg_hba.conf
    - text: "local  all  {{ pillar['mytardis_db_user'] }}  md5\n
{% if 'mytardis' not in salt['grains.get']('roles', []) %}
host  all  {{ pillar['mytardis_db_user'] }}  118.138.240.0/22   md5\n
host  all  {{ pillar['mytardis_db_user'] }}  127.0.0.1/32  md5\n
{% endif %}"
    - require:
        - pkg: postgresql
{% endif %}

  service:
    - running
{% if grains['os_family'] == "RedHat" %}
    - name: postgresql-9.3
{% else %}
    - name: postgresql
{% endif %}
    - require:
        - pkg: postgresql-server
{% if grains['os_family'] == 'Debian' %}
        - file: postgresql-server
{% endif %}
    - require_in:
        - postgres_database: mytardis_db
        - postgres_user: mytardis_db_user

{% if grains['os_family'] == 'Debian' %}
  cmd.run:
    - name: service postgresql restart
    - require:
      - file: postgresql-server
    - require_in:
        - postgres_database: mytardis_db
        - postgres_user: mytardis_db_user
{% endif %}

{% if grains['os_family'] == "RedHat" %}
  cmd.run:
    - name: service postgresql-9.3 initdb
    - unless: ls /var/lib/pgsql/9.3/data/base
    - require_in:
        - service: postgresql-server
{% endif %}
