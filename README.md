<img src="https://github.com/KMCS-NII/fixfix/blob/master/logo/FixFix_logodata2.png" width=300 alt="FixFix">

About FixFix
------------
FixFix is a web-based editor for fixations detected in gaze datasets of reading activities.

It features I-DT algorithm for fixation detection, and allows fixations to be dragged, singly or in groups, to new positions. The main purpose is editing reading gaze datasets, primarily in order to produce golden datasets for reading gaze research. It also has merit as a visualisation tool of reading gaze datasets.

Installation
------------
FixFix is written in Ruby (and CoffeeScript) as a Rack application, and can be run standalone (mainly for debugging purposes), or using any Rack container like Puma, Unicorn or Passenger.

References
----------
* Yamaya, A., Topić, G., Martínez-Gómez, P., & Aizawa, A. (2015). Dynamic-Programming–Based Method for Fixation-to-Word Mapping. In Intelligent Decision Technologies (pp. 649-659). Springer International Publishing.
* Goran Topić, Akito Yamaya, Akiko Aizawa, Pascual Martínez-Gómez: “FixFix: Fixing the Fixations (Demo).” 2016 Symposium on Eye Tracking Research & Applications (ETRA 2016), Charleston, USA. March 2016.
* Akito Yamaya, Goran Topić, Akiko Aizawa: “Fixation-to-Word Mapping with Classification of Saccades.” ACM 2016 International Conference on Intelligent User Interfaces (IUI 2016), Sonoma, USA, March 2016.

Documentation
-------------
English manual is available <a href="https://github.com/KMCS-NII/fixfix/blob/master/documents/manual_en.pdf">here</a>.

Acknowledgements
----------------

Libraries:

* [jQuery](http://jquery.com/)
* [jQuery SVG](http://keith-wood.name/svg.html)
* [jQuery File Tree](http://www.abeautifulsite.net/blog/2008/03/jquery-file-tree/) - modified
* [jQuery Ajax Reviver](https://github.com/quickredfox/jquery-ajax-reviver)
* [jQuery Mousewheel](https://github.com/brandonaaron/jquery-mousewheel) - modified
* [jQuery contextMenu](http://medialize.github.io/jQuery-contextMenu/)
* [jQuery noUiSlider](http://refreshless.com/nouislider/)

Ideas:

* [SVGPan](https://code.google.com/p/svgpan/)
* [StackOverflow: SVG coordinates with transform matrix](http://stackoverflow.com/a/5223921/240443)
* [Javascript: The Definitive Guide - Handling mousewheel events](https://www.inkling.com/read/javascript-definitive-guide-david-flanagan-6th/chapter-17/handling-mousewheel-events)
