# plugins/

Plugins de Roblox Studio deste projeto. Doc completo:
[docs/19-DEBUG-BRIDGE.md](../docs/19-DEBUG-BRIDGE.md).

## AvbDebug — ponte de debug para agentes

Instalar (compila e joga o `.rbxm` em `%LOCALAPPDATA%\Roblox\Plugins`):

```powershell
.\scripts\install-plugin.ps1
```

Usar:

```bash
lune run scripts/debug-bridge.luau          # terminal 1, deixa rodando
lune run scripts/avb-debug.luau ping        # terminal 2 (agente)
lune run scripts/avb-debug.luau sync        # Studio está com o código do repo?
lune run scripts/avb-debug.luau errors      # erros do Output do playtest
```

Alterou o plugin? `stylua plugins`, `selene plugins`, rode o instalador de novo
e reabra o Studio.
