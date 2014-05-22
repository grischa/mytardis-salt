{% set mytardis_inst_dir =
        pillar['mytardis_base_dir']~"/"~pillar['mytardis_branch'] %}

# create mytardis user under which to run the server
mytardis-user:
  user.present:
    - name: {{ pillar['mytardis_user'] }}
    - shell: /bin/bash
    - home: {{ pillar['mytardis_base_dir'] }}
    - groups:
        - {{ pillar['mytardis_group'] }}
{% if salt['pillar.get']('mytardis_uid', False) %}
    - uid: {{ pillar['mytardis_uid'] }}
{% endif %}
{% if salt['pillar.get']('mytardis_gid', False) %}
    - gid: {{ pillar['mytardis_gid'] }}
{% endif %}
    - require:
        - group: mytardis-group

mytardis-group:
  group.present:
    - name: {{ pillar['mytardis_group'] }}
{% if salt['pillar.get']('mytardis_gid', False) %}
    - gid: {{ pillar['mytardis_gid'] }}
{% endif %}

{{ pillar['mytardis_base_dir'] }}:
  file.directory:
    - mode: 755
    - user: {{ pillar['mytardis_user'] }}
    - require:
      - user: mytardis-user

# install git
{{ pillar['git'] }}:
  pkg:
    - installed

set_git_email:
  module.run:
    - name: git.config_set
    - cwd: {{ pillar['mytardis_base_dir'] }}
    - setting_name: user.email
    - setting_value: "mytardis@mytardis.org"
    - user: {{ pillar['mytardis_user'] }}
    - is_global: True
    - require:
      - user: mytardis-user
      - file: {{ pillar['mytardis_base_dir'] }}
      - pkg: {{ pillar['git'] }}

set_git_user_name:
  module.run:
    - name: git.config_set
    - cwd: {{ pillar['mytardis_base_dir'] }}
    - setting_name: user.name
    - setting_value: "mytardis"
    - user: {{ pillar['mytardis_user'] }}
    - is_global: True
    - require:
      - module: set_git_email

git reset --hard HEAD:
  cmd.run:
    - cwd: {{ mytardis_inst_dir }}
    - user: {{ pillar['mytardis_user'] }}
    - onlyif: ls {{ mytardis_inst_dir }}/.git
    - require:
      - file: mytardis-git

force-branch-update:
  cmd.run:
{% if salt['pillar.get']('mytardis_branch', 'master') != "develop" %}
{% set other_branch = "develop" %}
{% else %}
{% set other_branch = "master" %}
{% endif %}
    - name: git checkout {{ other_branch }} && git branch -D {{ pillar.get('mytardis_branch', 'master') }} ; git fetch && git checkout -f {{ salt['pillar.get']('mytardis_branch', 'master') }}
    - cwd: {{ mytardis_inst_dir }}
    - user: {{ pillar['mytardis_user'] }}
    - require:
      - git: mytardis-git

mytardis-git:
  file.directory:
    - name: {{ mytardis_inst_dir }}
    - mode: 755
    - user: {{ pillar['mytardis_user'] }}
    - require:
      - file: {{ pillar['mytardis_base_dir'] }}
      - user: mytardis-user

  git.latest:
    - name: "{{ pillar['mytardis_repo'] }}"
    - rev: {{ salt['pillar.get']('mytardis_branch', 'master') }}
    - target: {{ mytardis_inst_dir }}
    - force: true
    - force_checkout: true
    - always_fetch: true
    - submodules: true
    - user: {{ pillar['mytardis_user'] }}
    - require:
      - module: set_git_user_name
      - cmd: git reset --hard HEAD

# install required packages for buildout.
requirements:
  pkg.installed:
    - names:
{% if grains['os_family'] == "Debian" %}
      - python-dev
      - libsasl2-dev
      - libxml2-dev
      - libxslt1-dev
      - make
{% if grains['os'] == 'Debian' and grains['osrelease'] <= '6.0.6' %}      - libmagickwand3
{% elif grains['os'] == 'Ubuntu' and grains['osrelease'] <= '12.04' %}      - libmagickwand4
{% else %}      - libmagickwand5{% endif %}
{% if grains['os'] == 'Debian' and grains['osrelease'] <= '6.0.6' %}      - libpq-dev
{% else %}      - postgresql-server-dev-all{% endif %}
      - pkg-config
      - libgraphviz-dev
      - libevent-dev
{% elif grains['os_family'] == "RedHat" %}
      - python-devel
      - libgsasl-devel
      - libxml2-devel
      - libxslt-devel
      - ImageMagick
      - postgresql-devel
      - graphviz-devel
{% if grains['os'] == "RedHat" %}
      - compat-libevent14-devel
{% else %}
      - libevent-devel-1.4.13
{% endif %}
{% endif %}

{% if grains['os_family'] == "RedHat" %}
# only available in newest salt version
devtools:
  module.run:
    - name: pkg.group_install
    - m_name: 'development'
    - require_in:
      - cmd: buildout
{% endif %}

buildout-cfg:
  file.managed:
    - name: {{ mytardis_inst_dir }}/buildout-salt.cfg
    - source: salt://mytardis/templates/buildout-salt.cfg
    - template: jinja
    - context:
        mytardis_dir: {{ mytardis_inst_dir }}
    - user: {{ pillar['mytardis_user'] }}
    - require:
        - user: mytardis-user
        - file: {{ pillar['mytardis_base_dir'] }}
    - watch:
        - cmd: force-branch-update

# create settings.py
settings.py:
  file.managed:
    - name: {{ mytardis_inst_dir }}/tardis/settings.py
    - source: salt://mytardis/templates/settings.py
    - template: jinja
    - user: {{ pillar['mytardis_user'] }}
    - require:
        - cmd: force-branch-update
        - user: mytardis-user

# run shell script that builds mytardis with buildout and populates the db
bootstrap:
  cmd.run:
    - name: python bootstrap.py -v 1.7.0 -c buildout-salt.cfg
    - cwd: {{ mytardis_inst_dir }}
    - user: {{ pillar['mytardis_user'] }}
    - unless: ls {{ mytardis_inst_dir }}/bin/buildout
    - require:
        - file: buildout-cfg
        - cmd: force-branch-update
        - pkg: requirements
        - file: {{ pillar['mytardis_base_dir'] }}

locations-fixture:
  file.managed:
    - name: {{ mytardis_inst_dir }}/tardis/tardis_portal/fixtures/locations.json
    - source: salt://mytardis/templates/locations.json
    - template: jinja
    - context:
        default_fs_path: {{ mytardis_inst_dir }}/var/store
        default_st_path: {{ mytardis_inst_dir }}/var/staging
    - user: {{ pillar['mytardis_user'] }}
    - watch:
        - cmd: force-branch-update
        - git: mytardis-git

load-fixtures:
  cmd.run:
    - name: bin/django loaddata locations.json
    - cwd: {{ mytardis_inst_dir }}
    - user: {{ pillar['mytardis_user'] }}
    - require:
        - cmd: django-sync-migrate
    - watch:
        - file: locations-fixture

django-sync-migrate:
  cmd.run:
    - name: bin/django syncdb --noinput --migrate
    - cwd: {{ mytardis_inst_dir }}
    - user: {{ pillar['mytardis_user'] }}
    - watch:
        - file: settings.py
        - cmd: force-branch-update
        - git: mytardis-git
        - cmd: buildout
    - require:
        - postgres_database: {{ pillar['mytardis_db'] }}

bin/django update_permissions:
  cmd.run:
    - cwd: {{ mytardis_inst_dir }}
    - user: {{ pillar['mytardis_user'] }}
    - watch:
        - cmd: django-sync-migrate
    - require_in:
        - file: {{ mytardis_inst_dir }}/wsgi.py

buildout:
  cmd.run:
    - name: bin/buildout -N -c buildout-salt.cfg
    - cwd: {{ mytardis_inst_dir }}
    - user: {{ pillar['mytardis_user'] }}
    - watch:
        - cmd: force-branch-update
        - git: mytardis-git
        - file: buildout-cfg
        - cmd: bootstrap

{% if salt['pillar.get']('provide_staticfiles', False) %}
static_files_directory:
  file.directory:
    - name: "{{ salt['pillar.get']('static_file_storage_path') }}"
    - mode: 755
    - makedirs: true
    - user: {{ pillar['mytardis_user'] }}
    - require:
        - user: mytardis-user

bin/django collectstatic --noinput:
  cmd.run:
    - cwd: {{ mytardis_inst_dir }}
    - user: {{ pillar['mytardis_user'] }}
    - watch:
        - file: settings.py
        - cmd: buildout
    - require:
        - file: static_files_directory
{% if 'nfs-mount' in salt['pillar.get']('roles', []) and '/srv/public_data' in salt['pillar.get']('nfs-servers', []) %}
        - mount: '/srv/public_data'
{% endif %}
{% endif %}

# load licenses
bin/django loaddata tardis/tardis_portal/fixtures/cc_licenses.json || true:
  cmd.run:
    - cwd: {{ mytardis_inst_dir }}
    - user: {{ pillar['mytardis_user'] }}
    - require:
        - cmd: django-sync-migrate

# common uwsgi configuration
{{ mytardis_inst_dir }}/wsgi.py:
  file.managed:
    - user: {{ pillar['mytardis_user'] }}
    - source: salt://mytardis/templates/wsgi.py
    - require:
        - cmd: bootstrap

celery-supervisor:
  file.managed:
    - name: /etc/supervisor/conf.d/celery.conf
    - contents: "[program:celeryd]\n\
directory={{ mytardis_inst_dir }}\n\
command={{ mytardis_inst_dir}}/bin/django celeryd --concurrency 5\n\
user={{ pillar['mytardis_user'] }}\n\
stdout_logfile={{ mytardis_inst_dir }}/celeryd.log\n\
redirect_stderr=true\n\
\n\
[program:celerybeat]\n\
directory={{ mytardis_inst_dir }}\n\
command={{ mytardis_inst_dir}}/bin/django celerybeat\n\
user={{ pillar['mytardis_user'] }}\n\
stdout_logfile={{ mytardis_inst_dir }}/celerybeat.log\n\
redirect_stderr=true\n\
"
    - require:
        - cmd: buildout
        - file: supervisord.conf
    - require_in:
        - cmd: supervisor-service-start

celeryd:
  supervisord:
{% if salt['pillar.get']('running_services:celeryd', true) or
 'celeryd' in salt['grains.get']('roles') %}
    - running
{% else %}
    - dead
{% endif %}
    - require:
        - cmd: supervisor-service-start

celerybeat:
  supervisord:
{% if salt['pillar.get']('running_services:celerybeat', true) or
 'celerybeat' in salt['grains.get']('roles') %}
    - running
{% else %}
    - dead
{% endif %}
    - require:
        - cmd: supervisor-service-start

# storage paths
{% if "file_store_path" in pillar %}
{{ pillar['file_store_path'] }}:
  file.directory:
    - mode: 775
    - user: {{ pillar['mytardis_user'] }}
    - group: {{ pillar['mytardis_group'] }}
    - require:
      - user: {{ pillar['mytardis_user'] }}
      - group: mytardis-group
{% endif %}

{% if "staging_path" in pillar %}
{{ pillar['staging_path'] }}:
  file.directory:
    - mode: 775
    - user: {{ pillar['mytardis_user'] }}
    - group: {{ pillar['mytardis_group'] }}
    - require:
      - user: {{ pillar['mytardis_user'] }}
      - group: mytardis-group
{% endif %}

{% if "sync_temp_path" in pillar %}
{{ pillar['sync_temp_path'] }}:
  file.directory:
    - mode: 775
    - user: {{ pillar['mytardis_user'] }}
    - group: {{ pillar['mytardis_group'] }}
    - require:
      - user: {{ pillar['mytardis_user'] }}
      - group: mytardis-group
{% endif %}

{% if "rsync_store_path" in pillar %}
{{ pillar['rsync_store_path'] }}:
  file.directory:
    - mode: 775
    - user: {{ pillar['mytardis_user'] }}
    - group: {{ pillar['mytardis_group'] }}
    - require:
      - user: {{ pillar['mytardis_user'] }}
      - group: mytardis-group
{% endif %}
