Get-ChildItem -Recurse -Filter * | Where-Object {$_.PsIsContainer -eq $True -and ($_.Name -notlike "images*" -and $_.Name -notlike ".git*") } | 
Foreach-Object { 
	$folder=$_.FullName
	Write-Output "processing dir ... $folder"

	Get-ChildItem $folder -Filter * |
		Foreach-Object {
			Write-Output "processing $_..."

			$original_file =$_.FullName
			$text = [IO.File]::ReadAllText($original_file) -replace "`r`n", "`n"
			[IO.File]::WriteAllText($original_file, $text)
		}
}