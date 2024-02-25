import os
import sys

link_app = 'kernel/link_app.S'
mode = "-Ddebug" if (len(sys.argv) >= 2 and sys.argv[1] == "debug") else ""

link_app_content = []

apps = os.listdir('user/bin')
apps.sort()

link_app_content.append(
r""".align 3
    .section .data
    .global _num_app
_num_app:
    .quad {}
""".format(len(apps))
)

for id in range(len(apps)):
    link_app_content.append("    .quad app_{}_start\n".format(id))
link_app_content.append("    .quad app_{}_end\n".format(len(apps) - 1))

link_app_data = r"""
.section .data
    .global app_{0}_start
    .global app_{0}_end
app_{0}_start:
    .incbin "zig-out/{1}"
app_{0}_end:
"""

app_id = 0
for app in apps:
    app = app[:app.find('.')]
    link_app_content.append(link_app_data.format(app_id, app))
    app_id = app_id + 1

with open(link_app, "w+") as f:
    f.writelines(link_app_content)

# build img
print("Building zcore-os.bin...")
os.system("zig build img {}".format(mode))

if mode == "-Ddebug":
    print("Building zcore-os excutable file for debug...")
    os.system("zig build {}".format(mode))

print("Done")
