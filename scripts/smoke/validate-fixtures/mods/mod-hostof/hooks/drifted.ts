function hostOf($) {
  return {
    cwd: () => $.session.cwd(),
    projectDir: () => $.env.get('CLAUDE_PROJECT_DIR'),
  }
}

export const projectOf = $ => hostOf($).projectDir()
