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
      module RghostGuiaSindical
        extend self
        include RGhost unless self.include?(RGhost)
        RGhost::Config::GS[:external_encoding] = Brcobranca.configuration.external_encoding
        RGhost::Config::GS[:default_params] << '-dNOSAFER'

        # Gera o boleto em usando o formato desejado [:pdf, :jpg, :tif, :png, :ps, :laserjet, ... etc]
        #
        # @return [Stream]
        # @see http://wiki.github.com/shairontoledo/rghost/supported-devices-drivers-and-formats Veja mais formatos na documentação do rghost.
        # @see Rghost#modelo_sindical Recebe os mesmos parâmetros do Rghost#modelo_sindical.
        def to_sindical(formato, options = {})
          modelo_sindical(self, options.merge!(formato: formato))
        end

        # Gera o boleto em usando o formato desejado [:pdf, :jpg, :tif, :png, :ps, :laserjet, ... etc]
        #
        # @return [Stream]
        # @see http://wiki.github.com/shairontoledo/rghost/supported-devices-drivers-and-formats Veja mais formatos na documentação do rghost.
        # @see Rghost#modelo_sindical Recebe os mesmos parâmetros do Rghost#modelo_sindical.
        def lote_sindical(boletos, options = {})
          modelo_sindical_multipage(boletos, options)
        end

        #  Cria o métodos dinâmicos (to_pdf, to_gif e etc) com todos os fomátos válidos.
        #
        # @return [Stream]
        # @see Rghost#modelo_sindical Recebe os mesmos parâmetros do Rghost#modelo_sindical.
        # @example
        #  @boleto.to_pdf #=> boleto gerado no formato pdf
        def method_missing(m, *args)
          method = m.to_s
          if method.start_with?('to_')
            modelo_sindical(self, (args.first || {}).merge!(formato: method[3..-1]))
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
        def modelo_sindical(boleto, options = {})
          doc = Document.new paper: :A4 # 210x297

          template_path = File.join(File.dirname(__FILE__), '..', '..', 'arquivos', 'templates', 'modelo_sindical.eps')

          fail 'Não foi possível encontrar o template. Verifique o caminho' unless File.exist?(template_path)

          modelo_sindical_template(doc, boleto, template_path)
          modelo_sindical_cabecalho(doc, boleto)
          modelo_sindical_rodape(doc, boleto)

          # Gerando codigo de barra com rghost_barcode
          doc.barcode_interleaved2of5(boleto.codigo_barras, width: '10.3 cm', height: '1.3 cm', x: '0.7 cm', y: '1.2 cm') if boleto.codigo_barras

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
        def modelo_sindical_multipage(boletos, options = {})
          doc = Document.new paper: :A4 # 210x297

          template_path = File.join(File.dirname(__FILE__), '..', '..', 'arquivos', 'templates', 'modelo_sindical.eps')

          fail 'Não foi possível encontrar o template. Verifique o caminho' unless File.exist?(template_path)

          boletos.each_with_index do |boleto, index|
            modelo_sindical_template(doc, boleto, template_path)
            modelo_sindical_cabecalho(doc, boleto)
            modelo_sindical_rodape(doc, boleto)

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
        def modelo_sindical_template(doc, _boleto, template_path)
          doc.define_template(:template, template_path, x: '0.3 cm', y: '0 cm')
          doc.use_template :template

          doc.define_tags do
            tag :tarja, size: 46, color: '#FF0000'
            tag :grande, size: 13
            tag :medio, size: 11
          end
        end

        # Monta o cabeçalho do layout do boleto
        def modelo_sindical_cabecalho(doc, boleto)
          # INICIO Primeira parte do BOLETO
          # TARJA
          if boleto.tarja.present?
            doc.rotate 55
            doc.text_area "<tarja>#{boleto.tarja}</tarja>", x: '1 cm', y: '0 cm', width: '31 cm', text_align: :center
            doc.rotate -55
          end

          # LOGOTIPO do BANCO
          doc.image boleto.logotipo, x: '0.36 cm', y: '27 cm'
          # Dados
          doc.moveto x: '16 cm', y: '25.8 cm'
          doc.show boleto.data_vencimento.to_s_br
          doc.moveto x: '18.5 cm', y: '25.8 cm'
          doc.show boleto.competencia

          doc.moveto x: '0.7 cm', y: '25 cm'
          doc.show boleto.cedente.to_s[0..80]
          doc.moveto x: '20.3 cm', y: '25 cm'
          doc.show "#{boleto.codigo_central_sindical || '000'}.#{boleto.codigo_confederacao || '000'}.#{boleto.codigo_federacao || '000'}.#{boleto.codigo_sindical || '00000-0'}", align: :show_right

          doc.moveto x: '0.7 cm', y: '24.2 cm'
          doc.show boleto.cedente_logradouro.to_s[0..45]
          doc.moveto x: '9.1 cm', y: '24.2 cm'
          doc.show boleto.cedente_numero.to_s[0..9]
          doc.moveto x: '10.9 cm', y: '24.2 cm'
          doc.show boleto.cedente_complemento.to_s[0..22]
          doc.moveto x: '20.3 cm', y: '24.2 cm'
          doc.show boleto.documento_cedente.formata_documento.to_s, align: :show_right

          doc.moveto x: '0.7 cm', y: '23.45 cm'
          doc.show boleto.cedente_bairro.to_s[0..45]
          doc.moveto x: '8.8 cm', y: '23.45 cm'
          doc.show boleto.cedente_cep.to_s[0..9]
          doc.moveto x: '10.9 cm', y: '23.45 cm'
          doc.show boleto.cedente_cidade.to_s[0..45]
          doc.moveto x: '20 cm', y: '23.45 cm'
          doc.show boleto.cedente_uf.to_s[0..1]

          doc.moveto x: '0.7 cm', y: '22.2 cm'
          doc.show boleto.sacado.to_s[0..80]
          doc.moveto x: '20.3 cm', y: '22.2 cm'
          doc.show boleto.sacado_documento.formata_documento.to_s, align: :show_right

          doc.moveto x: '0.7 cm', y: '21.45 cm'
          doc.show boleto.sacado_logradouro.to_s[0..59]
          doc.moveto x: '10.9 cm', y: '21.45 cm'
          doc.show boleto.sacado_numero.to_s[0..9]
          doc.moveto x: '12.7 cm', y: '21.45 cm'
          doc.show boleto.sacado_complemento.to_s[0..24]

          doc.moveto x: '0.7 cm', y: '20.7 cm'
          doc.show boleto.sacado_cep.to_s[0..9]
          doc.moveto x: '2.7 cm', y: '20.7 cm'
          doc.show boleto.sacado_bairro.to_s[0..24]
          doc.moveto x: '10.9 cm', y: '20.7 cm'
          doc.show boleto.sacado_cidade.to_s[0..24]
          doc.moveto x: '17.2 cm', y: '20.7 cm'
          doc.show boleto.sacado_uf.to_s[0..1]
          doc.moveto x: '18.2 cm', y: '20.7 cm'
          doc.show boleto.codigo_atividade.to_s[0..2]

          doc.moveto x: '0.78 cm', y: '19.41 cm' if boleto.categoria.to_i == 1
          doc.moveto x: '4.09 cm', y: '19.41 cm' if boleto.categoria.to_i == 2
          doc.moveto x: '6.50 cm', y: '19.41 cm' if boleto.categoria.to_i == 3
          doc.moveto x: '8.87 cm', y: '19.41 cm' if boleto.categoria.to_i == 4
          doc.show 'X'
          doc.moveto x: '20.3 cm', y: '19.4 cm'
          doc.show boleto.valor_documento && boleto.valor_documento.to_currency, align: :show_right

          doc.moveto x: '0.7 cm', y: '18.63 cm'
          doc.show boleto.capital_social_empresa && boleto.capital_social_empresa.to_currency
          doc.moveto x: '8.2 cm', y: '18.63 cm'
          doc.show boleto.numero_empregado_contribuinte
          doc.moveto x: '0.7 cm', y: '17.9 cm'
          doc.show boleto.capital_social_estabelecimento && boleto.capital_social_estabelecimento.to_currency
          doc.moveto x: '8.2 cm', y: '17.9 cm'
          doc.show boleto.total_remuneracao_contribuinte && boleto.total_remuneracao_contribuinte.to_currency
          doc.moveto x: '8.2 cm', y: '17.18 cm'
          doc.show boleto.total_empregado_estabelecimento

          doc.text_area boleto.demonstrativo.to_s, x: '0.7 cm', y: '16.7 cm', width: '15 cm'

          doc.moveto x: '0.6 cm', y: '15.1 cm'
          doc.show "#{boleto.banco}-#{boleto.banco_dv}", tag: :grande
          doc.moveto x: '2.5 cm', y: '15.1 cm'
          doc.show boleto.codigo_barras.linha_digitavel, tag: :grande

          doc.moveto x: '0.7 cm', y: '14.33 cm'
          doc.show "#{boleto.codigo_central_sindical || '000'}.#{boleto.codigo_confederacao || '000'}.#{boleto.codigo_federacao || '000'}.#{boleto.codigo_sindical || '00000-0'}"
          doc.moveto x: '4.8 cm', y: '14.33 cm'
          doc.show boleto.nosso_numero_boleto
          doc.moveto x: '12.1 cm', y: '14.33 cm'
          doc.show boleto.valor_documento && boleto.valor_documento.to_currency, align: :show_right
          doc.moveto x: '12.6 cm', y: '14.33 cm'
          doc.show boleto.data_vencimento.to_s_br
          doc.moveto x: '16.9 cm', y: '14.33 cm'
          doc.show boleto.competencia

          # doc.moveto x: '5.2 cm', y: '14.1 cm'
          # doc.show boleto.numero_documento
          # FIM Primeira parte do BOLETO
        end

        # Monta o corpo e rodapé do layout do boleto
        def modelo_sindical_rodape(doc, boleto)
          # Variáveis
          sacado_com_doc_endereco = boleto.sacado
          sacado_com_doc_endereco = sacado_com_doc_endereco + " - CPF/CNPJ: #{boleto.sacado_documento.formata_documento}" if boleto.sacado_documento
          sacado_com_doc_endereco = sacado_com_doc_endereco + "\n#{boleto.sacado_endereco}" if boleto.sacado_endereco

          # INICIO Segunda parte do BOLETO BB
          # LOGOTIPO do BANCO
          doc.image boleto.logotipo, x: '0.36 cm', y: '12.1 cm'
          doc.moveto x: '5.2 cm', y: '12.2 cm'
          doc.show "#{boleto.banco}-#{boleto.banco_dv}", tag: :grande
          doc.moveto x: '7.5 cm', y: '12.2 cm'
          doc.show boleto.codigo_barras.linha_digitavel, tag: :grande
          doc.moveto x: '0.7 cm', y: '11.35 cm'
          doc.show boleto.local_pagamento
          doc.moveto x: '20.3 cm', y: '11.35 cm'
          doc.show boleto.data_vencimento.to_s_br, align: :show_right, tag: :medio if boleto.data_vencimento
          doc.moveto x: '0.7 cm', y: '10.56 cm'
          if boleto.cedente_endereco
            doc.text_area "#{boleto.cedente.to_s[0..75]}\n#{boleto.cedente_endereco.to_s[0..75]} - CPF/CNPJ: #{boleto.documento_cedente.formata_documento.to_s}", x: '0.7 cm', y: '10.56 cm', width: '15 cm', row_height: '0.35 cm'
          else
            doc.text_area "#{boleto.cedente}\nCPF/CNPJ: #{boleto.documento_cedente.formata_documento.to_s}", x: '0.7 cm', y: '10.56 cm', width: '15 cm', row_height: '0.35 cm'
          end
          doc.moveto x: '20.3 cm', y: '10.2 cm'
          doc.show boleto.agencia_conta_boleto, align: :show_right
          doc.moveto x: '0.7 cm', y: '9.4 cm'
          doc.show boleto.data_documento.to_s_br if boleto.data_documento
          doc.moveto x: '4.2 cm', y: '9.4 cm'
          doc.show boleto.numero_documento
          doc.moveto x: '10 cm', y: '9.4 cm'
          doc.show boleto.especie_documento
          # doc.moveto x: '11.7 cm', y: '9.4 cm'
          # doc.show boleto.aceite
          doc.moveto x: '13 cm', y: '9.4 cm'
          doc.show boleto.data_processamento.to_s_br if boleto.data_processamento
          doc.moveto x: '20.3 cm', y: '9.4 cm'
          doc.show boleto.nosso_numero_boleto, align: :show_right
          doc.moveto x: '0.7 cm', y: '8.6 cm'
          doc.show "#{boleto.competencia}"
          doc.moveto x: '4.4 cm', y: '8.6 cm'
          doc.show "SIND"
          doc.moveto x: '6.4 cm', y: '8.6 cm'
          doc.show boleto.especie
          # doc.moveto x: '8 cm', y: '13.15 cm'
          # doc.show boleto.quantidade
          # doc.moveto :x => '11 cm' , :y => '13.15 cm'
          # doc.show boleto.valor.to_currency
          doc.moveto x: '20.3 cm', y: '8.6 cm'
          doc.show boleto.valor_documento && boleto.valor_documento.to_currency, align: :show_right
          doc.text_area boleto.instrucao.to_s, x: '0.7 cm', y: '7.6 cm', width: '15 cm'
          doc.text_area sacado_com_doc_endereco, x: '0.7 cm', y: '4 cm', width: '19.5 cm', row_height: '0.35 cm'

          if boleto.avalista && boleto.avalista_documento
            doc.moveto x: '2.5 cm', y: '2.85 cm'
            doc.show "#{boleto.avalista} - #{boleto.avalista_documento}"
          end
          # FIM Segunda parte do BOLETO
        end
      end # Base
    end
  end
end
