# -*- encoding: utf-8 -*-

begin
  require 'rghost'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  gem 'rghost'
  require 'rghost'
end

begin
  require 'rghost_barcode'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  gem 'rghost_barcode'
  require 'rghost_barcode'
end

module Brcobranca
  module Boleto
    module Template
      # Templates para usar com Rghost
      module Rghost
        extend self
        include RGhost unless self.include?(RGhost)
        RGhost::Config::GS[:external_encoding] = Brcobranca.configuration.external_encoding
        RGhost::Config::GS[:default_params] << '-dNOSAFER'

        # Gera o boleto em usando o formato desejado [:pdf, :jpg, :tif, :png, :ps, :laserjet, ... etc]
        #
        # @return [Stream]
        # @see http://wiki.github.com/shairontoledo/rghost/supported-devices-drivers-and-formats Veja mais formatos na documentação do rghost.
        # @see Rghost#modelo_generico Recebe os mesmos parâmetros do Rghost#modelo_generico.
        def to(formato, options = {})
          modelo_generico(self, options.merge!(formato: formato))
        end

        # Gera o boleto em usando o formato desejado [:pdf, :jpg, :tif, :png, :ps, :laserjet, ... etc]
        #
        # @return [Stream]
        # @see http://wiki.github.com/shairontoledo/rghost/supported-devices-drivers-and-formats Veja mais formatos na documentação do rghost.
        # @see Rghost#modelo_generico Recebe os mesmos parâmetros do Rghost#modelo_generico.
        def lote(boletos, options = {})
          modelo_generico_multipage(boletos, options)
        end

        #  Cria o métodos dinâmicos (to_pdf, to_gif e etc) com todos os fomátos válidos.
        #
        # @return [Stream]
        # @see Rghost#modelo_generico Recebe os mesmos parâmetros do Rghost#modelo_generico.
        # @example
        #  @boleto.to_pdf #=> boleto gerado no formato pdf
        def method_missing(m, *args)
          method = m.to_s
          if method.start_with?('to_')
            modelo_generico(self, (args.first || {}).merge!(formato: method[3..-1]))
          else
            super
          end
        end

        private

        # Retorna um stream pronto para gravação em arquivo.
        #
        # @return [Stream]
        # @param [Boleto] Instância de uma classe de boleto.
        # @param [Hash] options Opção para a criação do boleto.
        # @option options [Symbol] :resolucao Resolução em pixels.
        # @option options [Symbol] :formato Formato desejado [:pdf, :jpg, :tif, :png, :ps, :laserjet, ... etc]
        def modelo_generico(boleto, options = {})
          doc = Document.new paper: :A4 # 210x297

          template_path = File.join(File.dirname(__FILE__), '..', '..', 'arquivos', 'templates', 'modelo_generico.eps')

          fail 'Não foi possível encontrar o template. Verifique o caminho' unless File.exist?(template_path)

          modelo_generico_template(doc, boleto, template_path)
          modelo_generico_cabecalho(doc, boleto)
          modelo_generico_rodape(doc, boleto)

          # Gerando codigo de barra com rghost_barcode
          doc.barcode_interleaved2of5(boleto.codigo_barras, width: '10.3 cm', height: '1.3 cm', x: '0.7 cm', y: '2.3 cm') if boleto.codigo_barras

          # Gerando stream
          formato = (options.delete(:formato) || Brcobranca.configuration.formato)
          resolucao = (options.delete(:resolucao) || Brcobranca.configuration.resolucao)
          doc.render_stream(formato.to_sym, resolution: resolucao)
        end

        # Retorna um stream para multiplos boletos pronto para gravação em arquivo.
        #
        # @return [Stream]
        # @param [Array] Instâncias de classes de boleto.
        # @param [Hash] options Opção para a criação do boleto.
        # @option options [Symbol] :resolucao Resolução em pixels.
        # @option options [Symbol] :formato Formato desejado [:pdf, :jpg, :tif, :png, :ps, :laserjet, ... etc]
        def modelo_generico_multipage(boletos, options = {})
          doc = Document.new paper: :A4 # 210x297

          template_path = File.join(File.dirname(__FILE__), '..', '..', 'arquivos', 'templates', 'modelo_generico.eps')

          fail 'Não foi possível encontrar o template. Verifique o caminho' unless File.exist?(template_path)

          boletos.each_with_index do |boleto, index|
            modelo_generico_template(doc, boleto, template_path)
            modelo_generico_cabecalho(doc, boleto)
            modelo_generico_rodape(doc, boleto)

            # Gerando codigo de barra com rghost_barcode
            doc.barcode_interleaved2of5(boleto.codigo_barras, width: '10.3 cm', height: '1.3 cm', x: '0.7 cm', y: '2.3 cm') if boleto.codigo_barras
            # Cria nova página se não for o último boleto
            doc.next_page unless index == boletos.length - 1
          end
          # Gerando stream
          formato = (options.delete(:formato) || Brcobranca.configuration.formato)
          resolucao = (options.delete(:resolucao) || Brcobranca.configuration.resolucao)
          doc.render_stream(formato.to_sym, resolution: resolucao)
        end

        # Define o template a ser usado no boleto
        def modelo_generico_template(doc, _boleto, template_path)
          doc.define_template(:template, template_path, x: '0.3 cm', y: '0 cm')
          doc.use_template :template

          doc.define_tags do
            tag :tarja, size: 46, color: '#FF0000'
            tag :grande, size: 13
            tag :medio, size: 11
          end
        end

        # Monta o cabeçalho do layout do boleto
        def modelo_generico_cabecalho(doc, boleto)
          # INICIO Primeira parte do BOLETO
          # LOGO CEDENTE
          # doc.image boleto.logo_cedente, x: '0.36 cm', y: '27.5 cm', width: '3.5 cm' if boleto.logo_cedente
          # TARJA
          if boleto.tarja.present?
            doc.rotate 55
            doc.text_area "<tarja>#{boleto.tarja}</tarja>", x: '1 cm', y: '0 cm', width: '31 cm', text_align: :center
            doc.rotate -55
          end
          # DADOS CEDENTE
          cabecalho_boleto = "<medio>#{boleto.cedente}</medio>"
          cabecalho_boleto << "\n#{boleto.cedente_endereco}" if boleto.cedente_endereco
          cabecalho_boleto << "\n#{boleto.documento_cedente.formata_documento}"
          doc.text_area cabecalho_boleto, x: '0.5 cm', y: '28 cm', width: '16 cm', row_height: '0.45 cm'

          if boleto.banco == '104'
            atendimento_banco = "SAC CAIXA: 0800 726 0101 (informações, reclamações, sugestões e elogios)"
            atendimento_banco << "\nPara pessoas com deficiência auditiva ou de fala: 0800 726 2496"
            atendimento_banco << "\nOuvidoria: 0800 725 7474"
            doc.text_area atendimento_banco, x: '0.5 cm', y: '25.2 cm', width: '16 cm', row_height: '0.3 cm'
          end

          # LOGOTIPO do BANCO
          doc.image boleto.logotipo, x: '0.36 cm', y: '23 cm'
          # Dados
          doc.moveto x: '5.2 cm', y: '23 cm'
          doc.show "#{boleto.banco}-#{boleto.banco_dv}", tag: :grande
          doc.moveto x: '7.5 cm', y: '23 cm'
          doc.show boleto.codigo_barras.linha_digitavel, tag: :grande
          doc.text_area boleto.cedente, x: '0.7 cm', y: '22.15 cm', width: '9.5 cm'
          doc.moveto x: '11 cm', y: '22.15 cm'
          doc.show boleto.agencia_conta_boleto
          doc.moveto x: '14 cm', y: '22.15 cm'
          doc.show boleto.especie
          doc.moveto x: '15.7 cm', y: '22.15 cm'
          doc.show boleto.quantidade
          doc.moveto x: '0.7 cm', y: '20.5 cm'
          doc.show boleto.numero_documento_impresso || boleto.numero_documento
          doc.moveto x: '7 cm', y: '20.5 cm'
          doc.show "#{boleto.documento_cedente.formata_documento}"
          doc.moveto x: '12 cm', y: '20.5 cm'
          doc.show boleto.data_vencimento.to_s_br
          doc.moveto x: '20.3 cm', y: '22.15 cm'
          doc.show boleto.nosso_numero_boleto, align: :show_right
          doc.moveto x: '20.3 cm', y: '20.5 cm'
          doc.show boleto.valor_documento && boleto.valor_documento.to_currency, align: :show_right
          doc.moveto x: '1.6 cm', y: '19.2 cm'
          doc.show "#{boleto.sacado.to_s[0..90]} - #{boleto.sacado_documento.formata_documento}"
          doc.moveto x: '1.6 cm', y: '18.90 cm'
          doc.show "#{boleto.sacado_endereco.to_s[0..110]}"
          doc.text_area boleto.demonstrativo.to_s, x: '0.7 cm', y: '18 cm', width: '14 cm'
          # FIM Primeira parte do BOLETO
        end

        # Monta o corpo e rodapé do layout do boleto
        def modelo_generico_rodape(doc, boleto)
          # Variáveis
          sacado_com_doc_endereco = boleto.sacado
          sacado_com_doc_endereco = sacado_com_doc_endereco + " - CPF/CNPJ: #{boleto.sacado_documento.formata_documento}" if boleto.sacado_documento
          sacado_com_doc_endereco = sacado_com_doc_endereco + "\n#{boleto.sacado_endereco}" if boleto.sacado_endereco
          # INICIO Segunda parte do BOLETO BB
          # LOGOTIPO do BANCO
          doc.image boleto.logotipo, x: '0.36 cm', y: '13.73 cm'
          doc.moveto x: '5.2 cm', y: '13.7 cm'
          doc.show "#{boleto.banco}-#{boleto.banco_dv}", tag: :grande
          doc.moveto x: '7.5 cm', y: '13.7 cm'
          doc.show boleto.codigo_barras.linha_digitavel, tag: :grande
          doc.moveto x: '0.7 cm', y: '12.85 cm'
          doc.show boleto.local_pagamento
          doc.moveto x: '20.3 cm', y: '12.85 cm'
          doc.show boleto.data_vencimento.to_s_br, align: :show_right, tag: :medio if boleto.data_vencimento
          doc.moveto x: '0.7 cm', y: '12 cm'
          if boleto.cedente_endereco
            doc.text_area "#{boleto.cedente.to_s[0..60]} - #{boleto.documento_cedente.formata_documento}\n#{boleto.cedente_endereco.to_s[0..75]}", x: '0.7 cm', y: '12.05 cm', width: '15 cm', row_height: '0.35 cm'
          else
            doc.text_area "#{boleto.cedente.to_s[0..60]} - #{boleto.documento_cedente.formata_documento}", x: '0.7 cm', y: '12.05 cm', width: '15 cm', row_height: '0.35 cm'
          end
          doc.moveto x: '20.3 cm', y: '12.05 cm'
          doc.show boleto.agencia_conta_boleto, align: :show_right
          doc.moveto x: '0.7 cm', y: '10.8 cm'
          doc.show boleto.data_documento.to_s_br if boleto.data_documento
          doc.moveto x: '4.2 cm', y: '10.8 cm'
          doc.show boleto.numero_documento_impresso || boleto.numero_documento
          doc.moveto x: '10 cm', y: '10.8 cm'
          doc.show boleto.especie_documento
          doc.moveto x: '11.7 cm', y: '10.8 cm'
          doc.show boleto.aceite
          doc.moveto x: '13 cm', y: '10.8 cm'
          doc.show boleto.data_processamento.to_s_br if boleto.data_processamento
          doc.moveto x: '20.3 cm', y: '10.9 cm'
          doc.show boleto.nosso_numero_boleto, align: :show_right
          doc.moveto x: '4.4 cm', y: '10 cm'
          if boleto.variacao
            doc.show "#{boleto.carteira}-#{boleto.variacao}"
          else
            doc.show (boleto.banco != '104' ? boleto.carteira : (boleto.carteira.to_i == 2 ? 'SG' : 'RG'))
          end
          doc.moveto x: '6.4 cm', y: '10 cm'
          doc.show boleto.especie
          # doc.moveto x: '8 cm', y: '13.15 cm'
          # doc.show boleto.quantidade
          # doc.moveto :x => '11 cm' , :y => '13.15 cm'
          # doc.show boleto.valor.to_currency
          doc.moveto x: '20.3 cm', y: '10 cm'
          doc.show boleto.valor_documento && boleto.valor_documento.to_currency, align: :show_right
          doc.text_area boleto.instrucao.to_s, x: '0.7 cm', y: '9.1 cm', width: '14 cm'
          doc.text_area sacado_com_doc_endereco, x: '0.7 cm', y: '5.2 cm', width: '19.5 cm', row_height: '0.35 cm'

          if boleto.avalista && boleto.avalista_documento
            doc.moveto x: '2.4 cm', y: '4.33 cm'
            doc.show "#{boleto.avalista} - #{boleto.avalista_documento}"
          end
          # FIM Segunda parte do BOLETO
        end
      end # Base
    end
  end
end
