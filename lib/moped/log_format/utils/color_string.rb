module Moped
  module LogFormat
    class ColorString
      Colors = {
        black:    "\e[30m",
        red:      "\e[31m",
        green:    "\e[32m",
        yellow:   "\e[33m",
        blue:     "\e[34m",
        magenta:  "\e[35m",
        cyan:     "\e[36m",
        white:    "\e[37m",
        default:  "\e[38m"
      }.freeze

      Backgrounds = {
        black:    "\e[40m",
        red:      "\e[41m",
        green:    "\e[42m",
        yellow:   "\e[43m",
        blue:     "\e[44m",
        magenta:  "\e[45m",
        cyan:     "\e[46m",
        white:    "\e[47m",
        default:  "\e[48m"
      }.freeze

      Clear = "\e[0m".freeze

      Styles = {
        bold:        "\e[1m",
        dim:         "\e[1m",
        underscore:  "\e[4m",
        blink:       "\e[5m",
        reverse:     "\e[7m",
        hidden:      "\e[8m"
      }.freeze

      attr_reader :string, :color, :background, :styles, :enable

      def initialize(string, enabled = false)
        @enable = enabled
        @string = string

        @color = Colors[:default]
        @background = Backgrounds[:default]
        @styles = []
      end

      def to_s
        if self.enable == true
          [styles.join, color, background, string, Clear].join
        else
          string
        end
      end
      alias_method :inspect, :to_s

      Colors.each do |color_name, value|
        define_method color_name do
          @color = Colors[color_name]
          self
        end
      end

      Backgrounds.each do |background_name, value|
        define_method :"on_#{background_name}" do
          @background = Backgrounds[background_name]
          self
        end
      end

      Styles.each do |style_name, value|
        define_method style_name do
          @styles << Styles[style_name]
          self
        end

        define_method :"no_#{style_name}" do
          @styles.delete Styles[style_name]
          self
        end
      end
    end
  end
end