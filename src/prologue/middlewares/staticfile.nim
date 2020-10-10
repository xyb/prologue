import std/[asyncdispatch, strutils, os, json, uri]

import ../core/context, ../core/middlewaresbase, ../core/request


proc isStaticFile(
  path: string, 
  dirs: openArray[string]
): tuple[hasValue: bool, filename, dir: string] =
  result = (false, "", "")
  var path = path.strip(chars = {'/'}, trailing = false)
  normalizePath(path)
  if not fileExists(path):
    return
  let file = splitFile(path)

  for dir in dirs:
    if dir.len == 0:
      continue
    if file.dir.startsWith(dir):
      return (true, file.name & file.ext, file.dir)

func normalizedStaticDirs(dirs: openArray[string]): seq[string] =
  ## Normalizes the path of static directories.
  result = newSeqOfCap[string](dirs.len)
  for item in dirs:
    let dir = item.strip(chars = {'/'}, trailing = false)
    if dir.len != 0:
      result.add dir
    normalizePath(result[^1])

proc staticFileMiddleware*(staticDirs: varargs[string]): HandlerAsync =
  # whether request.path in the static path of settings.
  let staticDirs = normalizedStaticDirs(staticDirs)
  result = proc(ctx: Context) {.async.} =
    let staticFileFlag = 
      if staticDirs.len != 0:
        isStaticFile(ctx.request.path.decodeUrl, staticDirs)
      else:
        (false, "", "")

    if staticFileFlag.hasValue:
      # serve static files
      await staticFileResponse(ctx, staticFileFlag.filename,
              staticFileFlag.dir,
              bufSize = ctx.getSettings("prologue").getOrDefault("bufSize").getInt(40960))
    else:
      await switch(ctx)
