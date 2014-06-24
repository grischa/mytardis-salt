# alphabetially sorted role configuration
mytardis:
#  '*':
#    - roles-as-grains
#    - minion-config

  'G@roles:nginx or I@roles:nginx':
    - match: compound
    - nginx

  'G@roles:mytardis or I@roles:mytardis':
    - match: compound
    - mytardis
#    - mytardis-db
    - mytardis.supervisor
    - mytardis.postgresql-client

  'G@roles:gunicorn or I@roles:gunicorn':
    - match: compound
    - mytardis.gunicorn

  'G@roles:rabbitmq or I@roles:rabbitmq':
    - match: compound
    - rabbitmq

  'G@roles:nfs-client':
    - match: compound
    - nfs-client

  'G@roles:nfs-mount':
    - match: compound
    - nfs-mount

  'roles:nfs-server':
    - match: pillar
    - nfs-server

  'G@roles:postgres-server or I@roles:postgres-server':
    - match: compound
    - postgres-server
    - mytardis-db
