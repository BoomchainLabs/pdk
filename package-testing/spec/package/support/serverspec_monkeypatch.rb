require 'beaker-rspec'

class Serverspec::Type::Command
  def run
    command_result
  end
end

option_keys = Specinfra::Configuration.singleton_class.const_get(:VALID_OPTIONS_KEYS).dup
option_keys << :cwd

Specinfra::Configuration.singleton_class.send(:remove_const, :VALID_OPTIONS_KEYS)
Specinfra::Configuration.singleton_class.const_set(:VALID_OPTIONS_KEYS, option_keys.freeze)
RSpec.configuration.add_setting :cwd

class Specinfra::Backend::BeakerCygwin
  old_create_script = instance_method(:create_script)

  define_method(:create_script) do |cmd|
    prepend_env(old_create_script.bind(self).call(cmd))
  end

  def prepend_env(script)
    cmd = []

    cmd << %(Set-Location -Path "#{get_config(:cwd)}") if get_config(:cwd)
    (get_config(:env) || {}).each do |k, v|
      cmd << %($env:#{k} = "#{v}")
    end
    cmd << script

    cmd.join("\n")
  end
end

class Specinfra::Backend::BeakerExec
  old_build_command = instance_method(:build_command)

  define_method(:build_command) do |cmd|
    prepend_env(old_build_command.bind(self).call(cmd))
  end

  def unescape(string)
    JSON.parse(%(["#{string}"])).first
  end

  def prepend_env(cmd)
    _, env, shell, command = cmd.match(%r{\A(env) (.+?) -c (.+)\Z}).to_a

    output = [env]
    (get_config(:env) || {}).each do |k, v|
      output << %(#{k}="#{v}")
    end
    output << shell << '-c'
    output << if get_config(:cwd)
                "'cd #{get_config(:cwd).shellescape} && #{unescape(command)}'"
              else
                command
              end

    output.join(' ')
  end
end
