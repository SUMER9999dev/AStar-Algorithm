set shell := ["powershell"]

start:
	concurrently "rojo sourcemap -o sourcemap.json --watch" "rojo serve"