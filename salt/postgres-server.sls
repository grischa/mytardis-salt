#!py


def run():
    grains = __grains__

    db_username = __pillar__['db_username']
    db_password = __pillar__['db_password']
    db_name = __pillar__['db_name']

    config = {}

    if grains['os_family'] == "RedHat":
        if grains['os'] == "CentOS":
            source = {'pgdg-centos93': 'http://yum.postgresql.org/9.3/'
                      'redhat/rhel-6-x86_64/pgdg-centos93-9.3-1.noarch.rpm'}
        else:
            source = {'pgdg-redhat93': 'http://yum.postgresql.org/9.3/'
                      'redhat/rhel-6-x86_64/pgdg-redhat93-9.3-1.noarch.rpm'}
        postgres_packages = ['postgresql93-server']
        postgresql_service_name = 'postgresql-9.3'
        command = [
            {'name': 'service postgresql-9.3 initdb'},
            {'unless': 'ls /var/lib/pgsql/9.3/data/base'},
            {'require_in': [
                {'service': 'postgresql-server'}]},
        ]
        config['pgsql-repo'] = {
            'pkg.installed': [
                {'require_in': [{'pkg': 'postgresql-server'}]},
                {'sources': [source]}
            ]}
    elif grains['os_family'] == 'Debian':
        postgres_packages = ['postgresql']
        postgresql_service_name = 'postgresql'
        command = [
            {'name': 'service postgresql restart'},
            {'require': [
                {'file': 'postgresql-server'}]},
            {'require_in': [
                {'postgres_database': 'database'},
                {'postgres_user': 'db_user'},
            ]}
        ]

    config['postgresql-server'] = {
        'pkg.installed': [
            {'names': postgres_packages}
        ]}

    if grains['os_family'] == 'Debian':
        config['postgresql-server']['file.managed'] = [
            {'name': '/etc/postgresql/9.3/main/pg_hba.conf'},
            {'source': 'salt://templates/pg_hba.conf'},
            {'mode': '644'},
            {'template': 'jinja'},
            {'require': [{'pkg': 'postgresql'}]},
        ]

    service_requirements = [{'pkg': 'postgresql-server'}]
    if grains['os_family'] == 'Debian':
        service_requirements.append({'file': 'postgresql-server'})
    config['postgresql-server']['service'] = [
        'running',
        {'name': postgresql_service_name},
        {'require': service_requirements},
        {'require_in': [
            {'postgres_database': 'database'},
            {'postgresql_user': 'db_user'},
        ]}
    ]
    config['postgresql-server']['cmd.run'] = command

    config['python-software-properties'] = {'pkg.installed': []}

    config['zfs-native'] = {
        'pkgrepo.managed': [
            {'ppa': 'zfs-native/stable'},
            {'require':
             [{'pkg': 'python-software-properties'}]}
        ]}

    config['ubuntu-zfs'] = {
        'pkg.installed': [
            {'require': [
                {'pkgrepo': 'zfs-native'}]}
        ]}

    config['zpool import -fa'] = {
        'cmd.run': [
            {'name': 'zpool import -fa; exit 0'},
            {'require': [
                {'pkg': 'ubuntu-zfs'}]}
        ]}
    db_store_name = 'store-synch-db-storage'
    config['zpool-create'] = {
        'cmd.run': [
            {'name': 'zpool create -f -m /srv/%s %s'
             ' raidz1 `lsblk -n -o NAME,TYPE|grep -v vda|grep -v vdb|cut -f 1'
             ' -d " "`' % tuple(
                 2 * [db_store_name])},
            {'unless': 'zpool list |grep %s' % db_store_name},
            {'require': [
                {'cmd': 'zpool import -fa'},
            ]},
        ]}

    db_store_dir = '/srv/%s/psqldata' % db_store_name
    config['copy-pg-datadir'] = {
        'cmd.run': [
            {'name': 'cp -a /var/lib/postgresql/9.3/main %s' % db_store_dir},
            {'unless': 'ls %s' % db_store_dir},
            {'require': [
                {'pkg': 'postgresql-server'},
                {'cmd': 'zpool-create'},
            ]},
        ]}
    pgsqlconf = '/etc/postgresql/9.3/main/postgresql.conf'
    config['postgresql.conf-datadir'] = {
        'file.replace': [
            {'name': pgsqlconf},
            {'pattern': '^(data_directory .+)$'},
            {'repl': "data_directory = '%s'" % db_store_dir},
            {'require': [
                {'cmd': 'copy-pg-datadir'}]}
        ]}
    config['postgresql.conf-listenip'] = {
        'file.replace': [
            {'name': pgsqlconf},
            {'pattern': '^(#?listen_addresses .+)$'},
            {'repl': "listen_addresses = 'localhost,%s'" %
             grains['ip_interfaces']['eth0'][0]},
        ]}

    config['pg_hba.conf'] = {
        'file.append': [
            {'name': '/etc/postgresql/9.3/main/pg_hba.conf'},
            {'text': 'local  all %s md5\n'
             'host all %s all md5\n' % tuple(2 * [db_username])},
            {'require': [
                {'file': 'postgresql-server'}]}
        ]}

    config['service postgresql restart'] = {
        'cmd.wait': [
            {'watch': [
                {'file': 'postgresql.conf-datadir'},
                {'file': 'postgresql.conf-listenip'},
                {'file': 'pg_hba.conf'}]}]}

    return config
