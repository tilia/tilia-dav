module Tilia
  module Dav
    module PropertyStorage
      module Backend
        module AbstractSequelTest
          # Should return an instance of \PDO with the current tables initialized,
          # and some test records.
          def sequel
            fail NotImplementedError
          end

          def backend
            Sequel.new(sequel)
          end

          def test_prop_find
            backend = self.backend

            prop_find = PropFind.new('dir', ['{DAV:}displayname'])
            backend.prop_find('dir', prop_find)

            assert_equal('Directory', prop_find.get('{DAV:}displayname'))
          end

          def test_prop_find_nothing_to_do
            backend = self.backend

            prop_find = PropFind.new('dir', ['{DAV:}displayname'])
            prop_find.set('{DAV:}displayname', 'foo')
            backend.prop_find('dir', prop_find)

            assert_equal('foo', prop_find.get('{DAV:}displayname'))
          end

          def test_prop_patch_update
            backend = self.backend

            prop_patch = PropPatch.new('{DAV:}displayname' => 'bar')
            backend.prop_patch('dir', prop_patch)
            prop_patch.commit

            prop_find = PropFind.new('dir', ['{DAV:}displayname'])
            backend.prop_find('dir', prop_find)

            assert_equal('bar', prop_find.get('{DAV:}displayname'))
          end

          def test_prop_patch_complex
            backend = self.backend

            complex = Xml::Property::Complex.new('<foo xmlns="DAV:">somevalue</foo>')

            prop_patch = PropPatch.new('{DAV:}complex' => complex)
            backend.prop_patch('dir', prop_patch)
            prop_patch.commit

            prop_find = PropFind.new('dir', ['{DAV:}complex'])
            backend.prop_find('dir', prop_find)

            assert_equal(complex, prop_find.get('{DAV:}complex'))
          end

          def test_prop_patch_custom
            backend = self.backend

            custom = Xml::Property::Href.new('/foo/bar/')

            prop_patch = PropPatch.new('{DAV:}custom' => custom)
            backend.prop_patch('dir', prop_patch)
            prop_patch.commit

            prop_find = PropFind.new('dir', ['{DAV:}custom'])
            backend.prop_find('dir', prop_find)

            assert_instance_equal(custom, prop_find.get('{DAV:}custom'))
          end

          def test_prop_patch_remove
            backend = self.backend

            prop_patch = PropPatch.new('{DAV:}displayname' => nil)
            backend.prop_patch('dir', prop_patch)
            prop_patch.commit

            prop_find = PropFind.new('dir', ['{DAV:}displayname'])
            backend.prop_find('dir', prop_find)

            assert_equal(nil, prop_find.get('{DAV:}displayname'))
          end

          def test_delete
            backend = self.backend
            backend.delete('dir')

            prop_find = PropFind.new('dir', ['{DAV:}displayname'])
            backend.prop_find('dir', prop_find)

            assert_equal(nil, prop_find.get('{DAV:}displayname'))
          end

          def test_move
            backend = self.backend
            # Creating a new child property.
            prop_patch = PropPatch.new('{DAV:}displayname' => 'child')
            backend.prop_patch('dir/child', prop_patch)
            prop_patch.commit

            backend.move('dir', 'dir2')

            # Old 'dir'
            prop_find = PropFind.new('dir', ['{DAV:}displayname'])
            backend.prop_find('dir', prop_find)
            assert_equal(nil, prop_find.get('{DAV:}displayname'))

            # Old 'dir/child'
            prop_find = PropFind.new('dir/child', ['{DAV:}displayname'])
            backend.prop_find('dir/child', prop_find)
            assert_equal(nil, prop_find.get('{DAV:}displayname'))

            # New 'dir2'
            prop_find = PropFind.new('dir2', ['{DAV:}displayname'])
            backend.prop_find('dir2', prop_find)
            assert_equal('Directory', prop_find.get('{DAV:}displayname'))

            # New 'dir2/child'
            prop_find = PropFind.new('dir2/child', ['{DAV:}displayname'])
            backend.prop_find('dir2/child', prop_find)
            assert_equal('child', prop_find.get('{DAV:}displayname'))
          end

          def test_deep_delete
            backend = self.backend
            prop_patch = PropPatch.new('{DAV:}displayname' => 'child')
            backend.prop_patch('dir/child', prop_patch)
            prop_patch.commit
            backend.delete('dir')

            prop_find = PropFind.new('dir/child', ['{DAV:}displayname'])
            backend.prop_find('dir/child', prop_find)

            assert_equal(nil, prop_find.get('{DAV:}displayname'))
          end
        end
      end
    end
  end
end
