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

postgresql-server:
  pkg.installed:
    - names:
    {% if grains['os_family'] == "RedHat" %}
      - postgresql93-server
    {% elif grains['os_family'] == 'Debian' %}
      - postgresql
    {% endif %}

{% if grains['os_family'] == 'Debian' %}
  file.managed:
    - name: /etc/postgresql/9.3/main/pg_hba.conf
    - source: salt://templates/pg_hba.conf
    - mode: 644
    - template: jinja
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
