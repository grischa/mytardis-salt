{% set mytardis_inst_dir =
        pillar['mytardis_base_dir']~"/"~pillar['mytardis_branch'] %}

/etc/supervisor/conf.d:
  file.directory:
    - makedirs: true

/var/log/supervisor:
  file.directory: []

supervisord.conf:
  file.managed:
    - name: /etc/supervisor/supervisord.conf
    - source: salt://mytardis/templates/supervisord.conf
    - require:
        - file: /etc/supervisor/conf.d
        - file: /var/log/supervisor
{% if grains['os_family'] == 'Debian' %}
        - pkg: supervisor
{% else %}
        - pip: supervisor
{% endif %}

{% if grains['os_family'] == 'Debian' %}
supervisor:
  pkg.installed: []

supervisor-service-start:
  cmd.run:
    - name: service supervisor start
    - require:
        - cmd: supervisor-service-stop

supervisor-service-stop:
  cmd.run:
    - name: service supervisor stop
    - require:
        - file: /etc/supervisor/supervisord.conf
        - file: {{ mytardis_inst_dir }}/wsgi.py
        - cmd: supervisorctl stop all

supervisorctl stop all:
  cmd.run:
    - require:
        - pkg: supervisor
        - file: supervisord.conf
{% else %}

python-pip:
  pkg.installed

supervisor:
  pip.installed:
    - name: "supervisor>=3.0a12"
    - require:
        - pkg: python-pip

/etc/init.d/supervisor:
  file.managed:
    - source: salt://mytardis/templates/init-d-supervisord
    - mode: 750
    - require:
        - file: /etc/sysconfig/supervisord

/etc/sysconfig/supervisord:
  file.managed:
    - source: salt://mytardis/templates/sysconfig-supervisord

chkconfig --add supervisor:
  cmd.run:
    - require:
        - pip: supervisor
        - file: /etc/init.d/supervisor

supervisor-service-start:
  cmd.run:
    - name: service supervisor restart
    - require:
        - file: /etc/supervisor/supervisord.conf
        - file: {{ mytardis_inst_dir }}/wsgi.py
        - cmd: supervisorctl stop all

supervisorctl stop all:
  cmd.run:
    - require:
        - pip: supervisor
        - file: supervisord.conf

supervisorctl start all:
  cmd.run:
    - require:
        - cmd: supervisor-service-start
{% endif %}
