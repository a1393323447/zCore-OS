import os
import sys

base_address = 0x80400000
step = 0x20000
linker = 'user/linker.ld'
mode = "-Ddebug" if (len(sys.argv) >= 2 and sys.argv[1] == "debug") else ""

app_id = 0
apps = os.listdir('user/bin')
apps.sort()
for app in apps:
    app = app[:app.find('.')]
    os.system('zig build app -DappName=%s %s' % (app, mode))
    app_id = app_id + 1
