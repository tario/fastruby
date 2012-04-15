=begin

This file is part of the fastruby project, http://github.com/tario/fastruby

Copyright (c) 2011 Roberto Dario Seminara <robertodarioseminara@gmail.com>

fastruby is free software: you can redistribute it and/or modify
it under the terms of the gnu general public license as published by
the free software foundation, either version 3 of the license, or
(at your option) any later version.

fastruby is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.  see the
gnu general public license for more details.

you should have received a copy of the gnu general public license
along with fastruby.  if not, see <http://www.gnu.org/licenses/>.

=end
require "fastruby/fastruby_sexp"
require "fastruby/sexp_extension_edges"
require "ruby_parser"
require "set"

class Object
  def to_fastruby_sexp
    self
  end
end

def fs(*args)
  if String === args.first
    tree = FastRuby::FastRubySexp.parse(args.first)

    if args.size > 1
      replacement_hash = {}
      args[1..-1].each do |arg|
        replacement_hash.merge!(arg)
      end

      tree = tree.transform{|subtree|
        if subtree.node_type == :call
          next replacement_hash[subtree[2]]
        elsif subtree.node_type == :lvar
          next replacement_hash[subtree[1]]
        else
          next nil
        end
      }    
    end 
    
    tree
  else
    sexp = FastRuby::FastRubySexp.new
    args.each {|subtree| sexp << subtree}
    sexp
  end
end

module FastRuby
  class Graph
    attr_reader :edges
    attr_reader :vertexes

    def initialize(hash = {})
      @edges = []
      @vertexes = Set.new
      @vertex_output = Hash.new

      hash.each do |orig,v|
        v.each do |dest|
          add_edge(orig,dest)
        end
      end
    end
 
    def add_edge(orig,dest)
      @vertexes << orig
      @vertexes << dest

      @vertex_output[orig.object_id] ||= Set.new
      @vertex_output[orig.object_id] << dest

      @edges << [orig,dest]
    end

    def each_vertex_output(vertex,&blk)
      outputs = @vertex_output[vertex.object_id]
      if outputs
        blk ? outputs.each(&blk) : outputs
      else
        Set.new
      end
    end

    def each_path_from(vertex, history = [])
      outputs = each_vertex_output(vertex) - history.select{|h| h[0] == vertex }.map(&:last)
      outputs.delete(vertex)

      if outputs.count == 0
        yield [vertex]
        return
      end      

      outputs.each do |vo|
        each_path_from(vo,history+[[vertex,vo]]) do |subpath|
          yield [vertex]+subpath
        end
      end
    end
  end

  class FastRubySexp
    def self.from_sexp(value)
      return nil if value == nil
      return value if value.kind_of? FastRubySexp

      ary = FastRuby::FastRubySexp.new
      value.each do |x|
        ary << x.to_fastruby_sexp
      end
      ary
    end

    def transform(&blk)
      ret = FastRuby::FastRubySexp.from_sexp( blk.call(self) )
      unless ret
        ret = FastRuby::FastRubySexp.new
        each{|st2|
          if st2.respond_to?(:transform)
            ret << st2.transform(&blk)
          else
            ret << st2
          end
        } 
      end

      ret
    end

    def self.parse(code)
      from_sexp(RubyParser.new.parse(code))
    end

    def to_graph
      graph = Graph.new
      self.edges.each &graph.method(:add_edge)

      if ENV['FASTRUBY_GRAPH_VERTEX_CHECK'] == '1' 
        output_vertexes = [];

        self.walk_tree do |subtree|
          if graph.each_vertex_output(subtree).count == 0
            # vertexes with no output
            unless [:arglist,:scope].include? subtree.node_type 
              output_vertexes << subtree
              if output_vertexes.count > 1
                raise RuntimeError, "invalid output vertexes #{output_vertexes.map &:node_type}"
              end
            end
          end
        end
      end

      graph
    end

    def edges
      Edges.new(self)
    end

    def first_tree
      if respond_to? "first_tree_#{node_type}" 
        send("first_tree_#{node_type}")
      else
        return self[1].first_tree if self.count == 2 and self[1].respond_to? :node_type
        return self[1].first_tree if [:if,:block,:while,:until,:or,:and,:ensure].include? node_type
        return self[2].first_tree if [:lasgn,:iasgn,:gasgn,:cdecl].include? node_type

        self
      end    
    end

    def first_tree_rescue
      if self[1].node_type == :resbody
        return self
      else
        return self[1].first_tree
      end
    end
    
    def first_tree_return
      self[1] ? self[1].first_tree : self
    end

    alias first_tree_break first_tree_return
    alias first_tree_next first_tree_return 

    def first_tree_yield
      if self.size > 1
        self[-1].first_tree
      else
        self
      end
    end

    def first_tree_iter
      call_tree = self[1]
      recv = call_tree[1]
      if recv
        recv.first_tree
      else
        args_tree = call_tree[3]
        if args_tree.size > 1
          args_tree[1].first_tree
        else
          call_tree
        end
      end
    end

    def first_tree_call
      recv = self[1]
      if recv
        recv.first_tree
      else
        args_tree = self[3]
        if args_tree.size > 1
          args_tree[1].first_tree
        else
          self
        end
      end
    end

    def find_break(&blk)
      subarray = if node_type == :while
        []
      elsif node_type == :iter
        self[1..-2]
      elsif node_type == :break
        blk.call(self)
        return; nil
      else
        self[1..-1]
      end

      subarray.each do |subtree|
        if subtree.respond_to? :find_break
          subtree.find_break(&blk)
        end 
      end
    end
  end
end

class Sexp
  def to_fastruby_sexp
    FastRuby::FastRubySexp.from_sexp(self)
  end
end
