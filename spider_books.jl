using HTTP, Gumbo, Cascadia, DataFrames

"""
Script que puxa informações de todos os livros em https://books.toscrape.com/ e armazena em um DataFrame.
Campos: Titulo; Link; Preco; Estoque; Quantidade. 
"""
mutable struct Spider

    url::String
    html::HTMLDocument

    function Spider(url)
        html = HTTP.get(url).body |> String |> parsehtml
        new(url, html)
    end
end

function get_qtd_estoque(link::String)
   
    resp = text(Cascadia.matchFirst(sel"div.col-sm-6 p.instock", Spider(link).html.root))
    
    regex = Regex("\\d+")
    return match(regex, resp).match
end

function get_livros(sp::Spider)

    livros = []
    
    for livro in eachmatch(sel"article.product_pod", sp.html.root)

        titulo = Cascadia.matchFirst(sel"h3 a", livro).attributes["title"]
        link = Cascadia.matchFirst(sel"h3 a", livro).attributes["href"]
        preco = text(Cascadia.matchFirst(sel"div.product_price p.price_color", livro))
        estoque = text(Cascadia.matchFirst(sel"div.product_price p.instock", livro))
        
        if occursin("catalogue/", link)
            i = last(findfirst("catalogue/", link))
            link = link[i+1:end]
        end

        link = "https://books.toscrape.com/catalogue/" * link

        qtd = get_qtd_estoque(link)

        push!(livros, [titulo, link, preco, estoque, qtd])
    end

    try
        proximo = Cascadia.matchFirst(sel"div ul.pager li.next a", sp.html.root).attributes["href"]

        if !occursin("catalogue/", proximo)
            proximo = "catalogue/" * proximo
        end

        if occursin("catalogue/", sp.url)
            i = first(findfirst("catalogue/", sp.url))
            novo_url = sp.url[1:i-1]
            proximos_livros = get_livros(Spider(novo_url * proximo))
        else
            proximos_livros = get_livros(Spider(sp.url * proximo))
        end
        
        for livro in proximos_livros
            push!(livros, livro)
        end
        #println(proximo)
        return livros
    catch
        return livros
    end
end

teste = Spider("https://books.toscrape.com/")

df = DataFrame(Titulo = String[], Link = String[], Preco = String[], Estoque = String[], Quantidade = String[])

for livro in get_livros(teste)
    push!(df, livro)
end

print(df)