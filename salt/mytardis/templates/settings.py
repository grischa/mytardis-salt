from tardis.settings_changeme import *
{% set deployment = salt['grains.get']('deployment') %}

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': '{{ pillar['mytardis_db'] }}',
        'USER': '{{ pillar['mytardis_db_user'] }}',
        'PASSWORD': '{{ pillar['mytardis_db_pass'] }}',
{% if 'postgres.host' in pillar %}
        'HOST': '{{ salt['pillar.get']('postgres.host', '') }}',
{% else %}
        'HOST': '{{ salt['mine.get']('G@roles:postgres-server and G@deployment:' + deployment, 'network.ip_addrs', expr_form='compound').items()[0][1][0] }}',
{% endif %}
        'PORT': '',
{% if salt['pillar.get']('postgres_ssl', False) %}
        'OPTIONS': {
            'sslmode': 'require',
        },
{% endif %}
    }
}

# Disable faulty equipment app
INSTALLED_APPS = filter(lambda a: a != 'tardis.apps.equipment', INSTALLED_APPS)

INSTALLED_APPS += ('south',)

{% if "apps" in pillar %}
INSTALLED_APPS += (
{% for app in pillar['apps'] %}
    '{{ app }}',
{% endfor %}
    )
{% endif %}

{% if "secret_key" in pillar %}
SECRET_KEY = "{{ pillar['secret_key'] }}"
{% else %}
SECRET_KEY = None
{% endif %}

{% if "file_store_path" in pillar %}
FILE_STORE_PATH = "{{ pillar['file_store_path'] }}"
{% endif %}

{% if "staging_path" in pillar %}
STAGING_PATH = "{{ pillar['staging_path'] }}"
{% endif %}

{% if "sync_temp_path" in pillar %}
SYNC_TEMP_PATH = "{{ pillar['sync_temp_path'] }}"
{% endif %}


ALLOWED_HOSTS = ['{{ pillar['www_hostname'] }}', '{{ pillar['www_hostname'] }}.',
{% if salt['grains.get']('deployment', 'production') == 'test' %}'*'{% endif %}
]

{% if "django_settings" in pillar %}
{% for setting in pillar['django_settings'] %}
{{ setting }}
{% endfor %}
{% endif %}
