# SFTP CUSTOM POWERSHELL MODULE

## Requires
.NET winscp library - Can be downloaded with a task before running the module

## Instructions
Module is pretty straightforward, but it requires winscp binary dll. Define the variables in the example task.

## Secure option
If secure is set to true, remote host key signature must be provided. It can be obtained in many methods, through winscp for example.
If secure is set to false, any host key will be accepted and no verification will be made on remote host.

## Example Playbook
```yaml
---

# As first task, get winscpdll from anywhere you like
- name: Get WinSCPnet dll
  ansible.windows.win_get_url:
    url: '{{ vault_winSCPdll_url }}'
    dest: 'C:\WinSCPnet.dll'

# Then run your task defining those vars
- name: Download from CRB
  win_sftp:
    hostname: 'sftp.server.url'
    user: 'user'
    passwd: 'PWD'
    file_path: '/remote/path/to/file.txt'
    dest: 'C:\Path\To_Destination\File.txt'
    secure: false
    hostkey: 'ssh-rsa 2048 W8xxxxxxxxxxxxxxxxxxxxxxxxxxxxxcg'
```

## ToDo

- Solve the needing of winscp binary to be present on the machine
- Implement acceptnew option