#include <sys/stat.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int run(char ** args) {
  assert(args && args[0]);

  pid_t pid = fork();
  if (pid == 0) {
    execvp(args[0], args);
    abort();
  } else if (pid > 0) {
    int sl = 0;
    assert(0 <= waitpid(pid, &sl, 0));
    if (WIFEXITED(sl)) return WEXITSTATUS(sl);
  }

  fprintf(stderr, "failed to run child process: %s\n", args[0]);
  return 1;
}

static int cc(char * src, char * exe) {
  char * args[] = {
    "clang", "-Wall", "-g",
    "-framework", "AppKit",
    "-framework", "Metal",
    "-framework", "MetalKit",
    "-o", exe, src, 0 };
  return run(args);
}
#define compile(S) cc(S ".c", S)

int main(int argc, char ** argv) {
  mkdir("app.app", 0777);
  mkdir("app.app/Contents", 0777);
  mkdir("app.app/Contents/MacOS", 0777);

  if (cc("base.m", "app.app/Contents/MacOS/base")) return 1;
  if (cc("pipeline.m", "app.app/Contents/MacOS/pipeline")) return 1;

  return 0;
}
