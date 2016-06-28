require 'spec_helper'
require 'yaml'
require_relative 'uses_temp_files'
require 'fileutils'

describe Puppet::Type.type(:yaml_settings) do
  provider_class = described_class.provider(:yaml_settings_provider)

  let :type_instance do
    result = described_class.new(resource_hash)
    provider_instance = provider_class.new(resource_hash)
    result.provider = provider_instance
    result
  end

  let :result_hash do
    YAML.load_file(type_instance[:target])
  end

  describe 'bad parameters' do
    let :resource_hash do
      {
          title: 'foo',
          name: '/non_existant',
          values: { 'a' => '3' },
      }
    end

    context 'source is not a fully qualified path' do
      before { resource_hash[:source] = 'foobar' }
      it 'raises error' do
        expect { type_instance }.to raise_error Puppet::Error,
                                                /File paths must be fully qualified.*not 'foobar'/
      end
    end

    context 'target is not a fully qualified path' do
      before { resource_hash[:target] = 'foobar' }
      it 'raises error' do
        expect { type_instance }.to raise_error Puppet::Error,
                                                /File paths must be fully qualified.*not 'foobar'/
      end
    end

    context 'allow_new_values is not a boolean' do
      before { resource_hash[:allow_new_values] = 'falseyy'  }
      it 'raises error' do
        expect { type_instance }.to raise_error Puppet::Error,
                                                /Invalid value "falseyy". Valid values are true, false./
      end
    end

    context 'allow_new_file is not a boolean' do
      before { resource_hash[:allow_new_file] = 'falseyy' }
      it 'raises error' do
        expect { type_instance }.to raise_error Puppet::Error,
                                                /Invalid value "falseyy". Valid values are true, false./
      end
    end

    context 'values is not a hash' do
      before { resource_hash[:values] = ['sadf', 'sdfd'] }
      it 'raises error' do
        expect { type_instance }.to raise_error Puppet::Error,
                                                /Expected 'values' property to be a hash.*Array\)/
      end
    end

    context 'values has non-string key' do
      before { resource_hash[:values] = {1 => 'foo'} }
      it 'raises error' do
        expect { type_instance }.to raise_error Puppet::Error,
                                                /One of the keys of the 'values' hash .+found: 1/
      end
    end

    context 'values has empty key' do
      before { resource_hash[:values] = {'' => 'foo'} }
      it 'raises error' do
        expect { type_instance }.to raise_error Puppet::Error,
                                                /.+found: ""/
      end
    end

    context 'values has key that ends with a trailing slash' do
      before { resource_hash[:values] = {'foo/bar/' => 'foo'} }
      it 'raises error' do
        expect { type_instance }.to raise_error Puppet::Error,
                                                /.+could not match on position 7 the string.+/
      end
    end

    context 'values has key with non-matching component' do
      before { resource_hash[:values] = {'foo/baar/:sdfd' => 'foo'} }
      it 'raises error' do
        expect { type_instance }.to raise_error Puppet::Error,
                                                /.+could not match on position 8 the string.+/
      end
    end

    context 'values cannot be empty' do
      before { resource_hash.delete :values }
      it 'raises error' do
        expect { type_instance }.to raise_error Puppet::Error, /.+got absent+/
      end
    end
  end

  describe 'file from scratch, no template' do
    include UsesTempFiles

    let :resource_hash do
      {
          title: 'foo',
          name: full_path_for('out.yaml'),
          values: { "a/:'b'" => '42' },
      }
    end

    context 'when allow_new_file is false' do
      let :resource_hash do
        super().merge({ allow_new_file: false })
      end

      it 'raises error' do
        expect { type_instance.refresh }.to raise_error Puppet::Error,
                                                        /allow_new_file is false and .+ does not exist/
      end
    end

    context 'when allow_new_values is false' do
      let :resource_hash do
        super().merge({ allow_new_values: false })
      end

      it 'raises error' do
        expect { type_instance.refresh }.to raise_error Puppet::Error,
                                                        /Not allowing new values, so rejecting setting.+/
      end
    end

    it 'writes a new file whose content matches' do
      type_instance.refresh
      expect(result_hash).to eq({'a' => { b: '42' } })
    end

    context 'write root key' do
      let :resource_hash do
        super().merge({ values: { 'a' => 'b' } })
      end

      it 'writes a new file whose content matches' do
        type_instance.refresh
        expect(result_hash).to eq({'a' => 'b' })
      end
    end
  end

  describe 'file from scratch, with template' do
    include UsesTempFiles

    let :resource_hash do
      {
          title: 'foo',
          name: full_path_for('out.yaml'),
          source: File.expand_path('./spec/integration/files/template1.yaml'),
          values: { "foo/bar/baz" => '42' },
      }
    end

    context 'when allow_new_values is false' do
      let :resource_hash do
        super().merge({ allow_new_values: false })
      end

      context 'and we have new value' do
        it 'raises error' do
          expect { type_instance.refresh }.to raise_error Puppet::Error,
                                                          /Not allowing new values, so rejecting setting.+/
        end
      end

      context 'and we have no new value' do
        let :resource_hash do
          super().merge({ values: { "foo/string_key" => '42' } })
        end
        it 'writes a new file whose content matches' do
          type_instance.refresh
          res = {
              'foo' => {
                  'string_key' => '42',
                  :symbol_key  => 'The value',
              }
          }
          expect(result_hash).to eq(res)
        end
      end
    end

    it 'writes a new file whose content matches' do
      type_instance.refresh
      res = {
          'foo' => {
              'string_key' => 'string_value',
              :symbol_key  => 'The value',
              'bar'        => { 'baz' => '42' },
          }
      }
      expect(result_hash).to eq(res)
    end

    context 'with empty template' do
      let :resource_hash do
        super().merge({ source: '/dev/null' })
      end

      it 'writes a new file whose content matches' do
        type_instance.refresh
        res = {
            'foo' => { 'bar' => { 'baz' => '42' }, }
        }
        expect(result_hash).to eq(res)
      end
    end
  end

  describe 'existing file with no template' do
    include UsesTempFiles

    let :resource_hash do
      {
          title: 'foo',
          name: full_path_for('out.yaml'),
          values: { "foo/bar/baz" => '42' },
      }
    end

    before do
      data = {
          'foo' => { 'foo' => 'foo' },
      }
      IO.write(resource_hash[:name], data.to_yaml)
    end

    it 'writes a new file whose content matches' do
      type_instance.refresh
      res = {
          'foo' => {
              'foo' => 'foo',
              'bar' => { 'baz' => '42' },
          }
      }
      expect(result_hash).to eq(res)
    end
  end

  describe 'existing file with template' do
    include UsesTempFiles

    let :resource_hash do
      {
          title: 'foo',
          name: full_path_for('out.yaml'),
          source: File.expand_path('./spec/integration/files/template1.yaml'),
          values: { "foo/bar/baz" => '42' },
      }
    end

    before do
      data = {
          'foo' => { 'foo' => 'foo' }, # this should be wiped out
      }
      IO.write(resource_hash[:name], data.to_yaml)
    end

    it 'writes a new file whose content matches' do
      type_instance.refresh
      res = {
          'foo' => {
              'string_key' => 'string_value',
              :symbol_key  => 'The value',
              'bar'        => { 'baz' => '42' },
          }
      }

      expect(result_hash).to eq(res)
    end
  end

  describe 'with symbols in the values' do
    include UsesTempFiles

    let :resource_hash do
      {
          title: 'foo',
          name: full_path_for('out.yaml'),
          values: {
              ":'a'" => {
                  'b' => [Puppet::Pops::Types::TypeFactory.enum('c'), 'd']
              }
          },
      }
    end

    it 'writes a new file whose content matches' do
      skip 'Puppet version too old' unless defined?(Puppet::Pops::Types::TypeFactory)

      type_instance.refresh
      expect(result_hash).to eq({:a => { 'b' => [:c, 'd'] } })
    end
  end

  describe 'with undef values' do
    include UsesTempFiles

    let :resource_hash do
      {
          title: 'foo',
          name: full_path_for('out.yaml'),
          values: {
              ":'a'" => :undef,
          },
      }
    end

    it 'writes a new file whose content matches' do
      type_instance.refresh
      expect(result_hash).to eq({:a => nil })
    end
  end
end
