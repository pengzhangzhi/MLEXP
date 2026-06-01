# VHS tape — renders the MLEXP install snippet to a GIF.
#   Install VHS:  https://github.com/charmbracelet/vhs
#   Render:       vhs assets/quickstart.tape   ->   assets/quickstart.gif

Output assets/quickstart.gif

Set Theme "Catppuccin Mocha"
Set FontSize 18
Set Width 1000
Set Height 360
Set Padding 24
Set TypingSpeed 45ms

Type "# 1) add the marketplace and install the plugin"
Enter
Sleep 600ms
Type "claude plugin marketplace add https://github.com/pengzhangzhi/MLEXP.git"
Enter
Sleep 1200ms
Type "claude plugin install mlexp@mlexp"
Enter
Sleep 1500ms
Type "# 2) restart Claude Code, then just ask"
Enter
Sleep 600ms
Type "claude"
Enter
Sleep 800ms
Type "> /mlexp  help me design an ablation for my new attention variant"
Enter
Sleep 2500ms
