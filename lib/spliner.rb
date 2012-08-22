require 'matrix'
require 'spliner/spliner_section'

module Spliner
  VERSION = '1.0.1'

  # Spliner::Spliner provides cubic spline interpolation based on provided 
  # key points on a X-Y curve.
  #
  # == Example
  #
  #    require 'spliner'
  #    # Initialize a spline interpolation with x range 0.0..2.0
  #    my_spline = Spliner::Spliner.new [0.0, 1.0, 2.0], [0.0, 1.0, 0.5]
  #    # Perform interpolation on 31 values ranging from 0..2.0
  #    x_values = (0..30).map {|x| x / 30.0 * 2.0 }
  #    y_values = x_values.map {|x| my_spline[x] }
  #
  # Algorithm based on http://en.wikipedia.org/wiki/Spline_interpolation
  #
  class Spliner
    attr_reader :range

    # Creates a new Spliner::Spliner object to interpolate between
    # the supplied key points. 
    #
    # The key points shoul be in increaing X order. When duplicate X 
    # values are encountered, the spline is split into two or more 
    # discontinuous sections.
    #
    # The extrapolation method may be :linear by default, using a linear 
    # extrapolation at the curve ends using the curve derivative at the 
    # end points. The :hold method will use the Y value at the nearest end 
    # point of the curve.
    #
    # @overload initialize(key_points, options)
    #   @param key_points [Hash{Float => Float}] keys are X values in increasing order, values Y
    #   @param options [Hash]
    #   @option options [Range,String] :extrapolate ('0%') either a range or percentage, eg '10.0%'
    #   @option options [Symbol] :emethod (:linear) extrapolation method
    #
    # @overload initialize(x, y, options)
    #   @param x [Array(Float),Vector] the X values of the key points
    #   @param y [Array(Float),Vector] the Y values of the key points
    #   @param options [Hash]
    #   @option options [Range,String] :extrapolate ('0%') either a range or percentage, eg '10.0%'
    #   @option options [Symbol] :emethod (:linear) extrapolation method
    #
    def initialize(*param)
      # sort parameters from two alternative initializer signatures
      x, y = nil
      case param.first
      when Array, Vector
        xx,yy, options = param
        x = xx.to_a
        y = yy.to_a
      else
        points, options = param
        x = points.keys
        y = points.values
      end
      options ||= {}

      @sections = split_at_duplicates(x).map {|slice| SplinerSection.new x[slice], y[slice] }

      # Handle extrapolation option parameter
      options[:extrapolate].tap do |ex|
        case ex
        when /^\d+(\.\d+)?\s?%$/
          percentage = ex[/\d+(\.\d+)?/].to_f
          span = x.last - x.first
          extra = span * percentage * 0.01
          @range = (x.first - extra)..(x.last + extra)
        when Range
          @range = ex
        when nil
          @range = x.first..x.last
        else
          raise 'Unable to use extrapolation parameter'
        end
      end
      @extrapolation_method = options[:emethod] || :linear
    end

    # returns the ranges at each slice between duplicate X values
    def split_at_duplicates(x)
      # find all indices with duplicate x values
      dups = x.each_cons(2).map{|a,b| a== b}.each_with_index.select {|b,i| b }.map {|b,i| i}
      ([-1] + dups + [x.size - 1]).each_cons(2).map {|end0, end1| (end0 + 1)..end1 }
    end
    private :split_at_duplicates


    # returns an interpolated value
    def get(v)
      i = @sections.find_index {|section| section.range.member? v }
      if i
        @sections[i].get v
      elsif range.member? v
        extrapolate(v)
      else
        nil
      end
    end

    alias :'[]' :get 

    # The number of non-continuous sections used
    def sections
      @sections.size
    end



    def extrapolate(v)
      x, y, k = if v < first_x
                  [@sections.first.x.first, @sections.first.y.first, @sections.first.k.first]
                else
                  [@sections.last.x.last, @sections.last.y.last, @sections.last.k[-1]]
                end

      case @extrapolation_method
      when :hold
        y
      else
        y + k * (v - x)
      end
    end
    private :extrapolate

    def first_x
      @sections.first.x.first
    end
    private :first_x
  end
end
