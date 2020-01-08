module renderer;

import printed.canvas : IRenderingContext2D;
import common : RenderState;

private void renderTo(RenderState[] log, IRenderingContext2D ctx)
{
	import printed.canvas;
	with (ctx)
	{
		const k = pageWidth / cast(float) log[0].area.w;
		lineWidth(k);

		foreach(rs; log) with (rs.area) 
		{
			switch (rs.misc)
			{
				case 1:
					strokeStyle = brush("#00ff00");
					fillStyle = brush("#eee");
					fillRect(x*k, y*k, w*k, h*k);
					beginPath(x*k, y*k);
					lineTo((x+w)*k, y*k);
					lineTo((x+w)*k, (y+h)*k);
					lineTo(x*k, (y+h)*k);
					lineTo(x*k, y*k);
					closePath;
					fillAndStroke;
				break;
				case 2:
					fillStyle = brush("#ddd");
					fillRect(x*k, y*k, w*k, h*k);
				break;
				case 3:
					fillStyle = brush("#ccc");
					fillRect(x*k, y*k, w*k, h*k);
				break;
				default:
			}
		}
	}
}

void render(RenderState[] log, string filename)
{
	import std.typecons : Tuple, tuple;
	import std.file;
	import printed.canvas : PDFDocument, HTMLDocument, SVGDocument;
	
	{
		auto pdf = new PDFDocument (210, 297);
		log.renderTo(pdf);
		std.file.write(filename ~ ".pdf", pdf.bytes);
	}
	
	{
		auto svg = new SVGDocument (210, 297);
		log.renderTo(svg);
		std.file.write(filename ~ ".svg", svg.bytes);
	}
	
	{
		auto html = new HTMLDocument (210, 297);
		log.renderTo(html);
		std.file.write(filename ~ ".html", html.bytes);
	}
}