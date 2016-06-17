# yaml\_settings

#### Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with yaml_settings](#setup)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Creating files with only the keys specified](#creating-files-with-only-the-keys-specified)
1. [Reference](#reference)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

This module introduces a native type (`yaml_settings`) that allows for modifying
yaml files. It is similar to [_reidmv/yamlfile_][yamlfile], with the following
improvements:
  * forward slashes are allowed in key names,
  * portions of the key can be symbols,
  * it is possible to use a separate file as a template.

## Setup

The setting [_pluginsync_][pluginsync] needs to be enabled for at least one run
so that the ruby files of the native type are synced to the agents.

Note that _pluginsync_ is deprecated in Puppet 4, which defaults to enabling
_pluginsync_ when applying a non-cached catalog. See [PUP-5708][PUP-5708].

## Usage

This modules provides only one resource type: `yaml_settings`. Example usage:

	yaml_settings { '/tmp/foo.yaml':
		values => {
			'uuu/vvv/www' => { 'yyy' => 'zzz' },
		}
	}

This will create the file `/tmp/foo.yaml` (or modify it, if it already exists,
to add/change the value of `uuu/vvv/www`):

```yaml
--- 
  uuu: 
    vvv: 
      www: 
        yyy: zzz
```

If a key (portion) should include a `/`, then you must quote that key with a
single quote (`'`). If you need then a single quote, then you must double it. If
you prepend a colon (`:`) to the opening single quote, you will be referring to
a symbol key. Example:

	yaml_settings { '/tmp/foo.yaml':
		values => {
			"uuu/'a''b'/:'www'" => { 'yyy' => 'zzz' },
		}
	}

Will result in:

```yaml
--- 
  uuu: 
    "a'b": 
      !ruby/sym www: 
        yyy: zzz
```

The ugly `!rby/sym` and indentation of the first member doesn't happen in Puppet
4, as it uses a different YAML library. Beware that Puppet 4 behaves differently
with respect to number literals. While Puppet 3 converts these to strings,
Puppet 4 will not. So in Puppet 3, this example:

	yaml_settings { '/tmp/foo.yaml':
		values => { 'a' => 1 }
	}

will create

```yaml
--- 
  a: "1"
```

while in Puppet 4:

```yaml
---
a: 1
```

Because the Puppet 4 behavior makes more sense (notice that other types like
booleans and the `undef` symbol are also **not** converted under Puppet 3), this
module doesn't attempt to have Puppet 4 behave like Puppet 3 by converting the
numbers to strings.

In Puppet 4 or in versions of Puppet 3 with the future parser, there is also a
(rather hacky) way to specify symbols in the values, this is done by abusing the
`Enum` type:

	yaml_settings { '/tmp/foo.yml':
		values => { ":'a'" => { Enum['foo'] => [Enum['bar'], 'bar'] } }
	}

results in:

```yaml
---
:a:
  :foo:
  - :bar
  - bar
```

## Creating files with only the keys specified

This is not the main use case for this module, as this can be achieved without
dependencies by using `inline_template`:

	$values = {
		'uuu' => { 'vvv' => { 'www' => 'yyy' } },
	}
	file { '/tmp/foo.yaml':
		content => inline_template('<%= require "yaml"; @values.to_yaml %>'),
	}

will result in:

```yaml
--- 
  uuu: 
    vvv: 
      www: yyy
```

Nevertheless, you can still use this module, if you provide an empty file as a
template:

	yaml_settings { '/tmp/foo.yaml':
		source => '/dev/null',
		values => { 'a' => 'b', }
	}

## Reference

This is the full list of parameters:

	yaml_settings { 'my settings':
	  target           => '/tmp/foo.yaml', # defaults to title
	  source           => '/tmp/source.yaml',
	  allow_new_values => true,
	  allow_new_file   => true,
	  user             => 'root', # user used to read/write file,
								  # doesn't change ownership like 'file'!
	}

It autorequires a file resource with a title (not path!) equal to the `source`
parameter, if present in the catalog.

For more information, see [the type file source
file](lib/puppet/type/yaml_settings.rb).

## Limitations

There is no support yet for removing keys, though you can set them to `nil`.

## Development

Make sure that you run `rubocop` and `rake test` before committing.


  [yamlfile]: https://forge.puppet.com/reidmv/yamlfile
  [pluginsync]: https://docs.puppet.com/puppet/latest/reference/configuration.html#pluginsync
  [PUP-5708]: https://tickets.puppetlabs.com/browse/PUP-5708
