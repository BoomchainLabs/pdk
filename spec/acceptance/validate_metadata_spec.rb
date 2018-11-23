require 'spec_helper_acceptance'

describe 'Running metadata validation' do
  let(:junit_xsd) { File.join(RSpec.configuration.fixtures_path, 'JUnit.xsd') }
  let(:metadata_syntax_spinner) { %r{checking metadata syntax}i }
  let(:module_style_spinner) { %r{checking module metadata style}i }
  let(:task_style_spinner) { %r{checking task metadata style}i }

  include_context 'with a fake TTY'

  context 'with a metadata violation' do
    include_context 'in a new module', 'metadata_violation_module'

    before(:all) do
      metadata = JSON.parse(File.read('metadata.json'))
      metadata['dependencies'] = [
        { 'name' => 'puppetlabs-stdlib', 'version_requirement' => '>= 4.0.0' },
      ]
      File.open('metadata.json', 'w') do |f|
        f.puts metadata.to_json
      end
    end

    describe command('pdk validate metadata') do
      its(:exit_status) { is_expected.not_to eq(0) }
      its(:stdout) { is_expected.to match(%r{^warning:.*metadata\.json:.+open ended dependency}) }
      its(:stderr) { is_expected.to match(metadata_syntax_spinner) }
    end

    describe command('pdk validate metadata --format junit') do
      its(:exit_status) { is_expected.not_to eq(0) }
      its(:stderr) { is_expected.to match(metadata_syntax_spinner) }
      it_behaves_like :it_generates_valid_junit_xml

      its(:stdout) do
        is_expected.to have_junit_testsuite('metadata-json-lint').with_attributes(
          'failures' => eq(1),
          'tests'    => eq(1),
        )
      end

      its(:stdout) do
        is_expected.to have_junit_testcase.in_testsuite('metadata-json-lint').with_attributes(
          'classname' => 'metadata-json-lint.dependencies',
          'name'      => 'metadata.json',
        ).that_failed
      end
    end
  end

  context 'when incorrectly attempting to validate a specific file' do
    include_context 'in a new module', 'metadata_specific_module'

    before(:all) do
      FileUtils.cp('metadata.json', 'broken.json')
      broken_metadata = JSON.parse(File.read('broken.json'))
      broken_metadata['dependencies'] = [
        { 'name' => 'puppetlabs-stdlib', 'version_requirement' => '>= 4.0.0' },
      ]
      File.open('broken.json', 'w') do |f|
        f.puts broken_metadata.to_json
      end
    end

    describe command('pdk validate metadata --format junit') do
      its(:exit_status) { is_expected.to eq(0) }
      its(:stderr) { is_expected.to match(metadata_syntax_spinner) }

      its(:stdout) do
        is_expected.to have_xpath('/testsuites/testsuite[@name="metadata-json-lint"]/testcase').with_attributes(
          'name' => 'metadata.json',
        )
      end

      its(:stdout) do
        is_expected.not_to have_xpath('/testsuites/testsuite[@name="metadata-json-lint"]/testcase').with_attributes(
          'name' => 'broken.json',
        )
      end
    end

    describe command('pdk validate metadata --format junit broken.json') do
      its(:exit_status) { is_expected.to eq(0) }
      its(:stderr) { is_expected.not_to match(metadata_syntax_spinner) }

      its(:stdout) do
        is_expected.to have_xpath('/testsuites/testsuite[@name="metadata-json-lint"]').with_attributes(
          'tests' => '1',
          'skipped' => '1',
        )
      end

      its(:stdout) do
        is_expected.to have_xpath('/testsuites/testsuite[@name="metadata-json-lint"]/testcase').with_attributes(
          'name' => 'broken.json',
        )
      end
    end

    context 'metadata.json has errors' do
      before(:all) do
        FileUtils.cp('metadata.json', 'metadata.bak')
        FileUtils.cp('broken.json', 'metadata.json')
      end

      after(:all) do
        FileUtils.mv('metadata.bak', 'metadata.json')
      end

      describe command('pdk validate metadata --format junit broken.json') do
        its(:exit_status) { is_expected.to eq(0) }
        its(:stderr) { is_expected.not_to match(metadata_syntax_spinner) }

        its(:stdout) do
          is_expected.to have_junit_testsuite('metadata-json-lint').with_attributes(
            'skipped' => eq(1),
            'tests' => eq(1),
          )
        end

        its(:stdout) do
          is_expected.to have_xpath('/testsuites/testsuite[@name="metadata-json-lint"]/testcase').with_attributes(
            'name' => 'broken.json',
          )
        end
      end
    end
  end
end
