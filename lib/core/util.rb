#  Copyright (C) 2007 John J Kennedy III
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

#gem 'ruby-debug'

#Helper methods for string
class String 
  def starts_with(s) return slice(0..s.length-1) == s; end
  def ends_with(s) return slice(-s.length..-1) == s; end
  
  # return a new string with all occurance of s removed
  def remove(s) return gsub(s,''); end 

  # remove all occurance of s in a string
  def remove!(s) return gsub!(s,''); end 
end


class Array
  def sum
    total = 0
    each { |n| total += n }
    total
  end
  
  def count(o)
    total = 0
    for x in self
      total += 1 if o == x
    end
    total
  end

  # Counts all of the elements in this array
  # i.e. [1,1,1,'b',b'] => {1 => 3, 'b' => 2}
  # This is used with Arrays of CardTypes
  def to_count_hash
    result = {}
    result.default = 0
    for e in self
      result[e] += 1
    end
    result
  end

  #This divides an array into multiple sub-arrays that match the same criteria
  # i.e. [1,2,3,3,2,1,2,1,3].sort_and_partition{|o| o} => [[1,1,1], [2,2,2], [3,3,3]]
  def sort_and_partition
    tempHash = {}
    for element in self
      key = yield element
      tempHash[key] = [] unless tempHash.has_key?(key)
      tempHash[key] << element
    end
    result = []
    for key in tempHash.keys.sort
      result << tempHash[key]
    end
    result
  end

  #This removes elements from an array without making the array uniq.
  # i.e. [1,1,1,2].difference_without_uniq([1]) = [1,1,2]
  def difference_without_uniq(array2)
    result = self.dup
    for obj in array2
      i = result.index(obj)
      result.delete_at(i) if i
    end
    result
  end


end

class Hash
  #If the values in this hash are numbers, this will create a list with that many keys
  #i.e. {'a' => 3, 45 => 2}  becomes ['a', 'a', 'a', 45, 45]
  def to_flat_list
    result = []
    for key, count in self
      count.times do result << key end
    end
    result
  end
end

class SecurityException < StandardError; end


class Class
  
  #[method] the method name to chain to 
  #[before] should the new functionality be called before the old?
  def chain_method(method, before=false)
    i = 0
    new_method_name = "#{method}_#{i}"
    while instance_methods.include?(new_method_name)
      i += 1
      new_method_name = "#{method}_#{i}"
    end
    alias_method(new_method_name, method)
    define_method(method) do |*args|
      if before
        yield(self, method, *args)
        return self.send(new_method_name, *args)
      else
        result = self.send(new_method_name, *args)
        yield(self, method, *args)
        return result
      end
    end
  end
end

class Object
  def let
    yield self
  end
end

# Asserts that that the method is called from a specific caller
#[file] can be nil, :this_file, or the actual filename
#[method] is the method name
def assert_caller(method=nil, file=nil)
  file = __FILE__ if file == :this_file
  if file and file != caller[0].split[0].split(':')[0]
    raise SecurityException("Called from an invalid file")
  end

  if method and method != caller[0].split[1][1..-2]
    raise SecurityException("Called from an invalid method")
  end
end
