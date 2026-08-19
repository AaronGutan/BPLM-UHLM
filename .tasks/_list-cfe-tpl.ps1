$root = 'E:\1C\AY\BPLM-UHLM-XML\acclmcopy-cfe-consolidation'
Get-ChildItem -LiteralPath $root -Recurse -Filter 'Template.txt' |
	Where-Object { $_.FullName -match 'ExchangePlans' } |
	ForEach-Object {
		Write-Host ("{0}`tsize={1}" -f $_.FullName.Substring($root.Length), $_.Length)
	}
