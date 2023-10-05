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
    lines = []
    lines_before = []
    with open(linker, 'r') as f:
        for line in f.readlines():
            lines_before.append(line)
            line = line.replace(hex(base_address), hex(base_address+step*app_id))
            lines.append(line)
    with open(linker, 'w+') as f:
        f.writelines(lines)
    os.system('zig build app -DappName=%s %s' % (app, mode))
    print('[build.py] application %s start with address %s' %(app, hex(base_address+step*app_id)))
    with open(linker, 'w+') as f:
        f.writelines(lines_before)
    app_id = app_id + 1