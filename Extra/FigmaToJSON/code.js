// Show the UI with a specific width and height
figma.showUI(__html__, { width: 450, height: 600 });

// Helper function to extract all relevant properties from a node
function serializeNode(node) {
	const obj = {};

	// A comprehensive list of properties to extract, covering sizing, positioning,
	// typography, autolayout, effects, styling, and basic metadata.
	const props = [
		"id",
		"name",
		"type",
		"x",
		"y",
		"width",
		"height",
		"rotation",
		"layoutAlign",
		"layoutGrow",
		"opacity",
		"blendMode",
		"isMask",
		"visible",
		"locked",
		"fills",
		"strokes",
		"strokeWeight",
		"strokeAlign",
		"cornerRadius",
		"cornerSmoothing",
		"characters",
		"fontName",
		"fontSize",
		"letterSpacing",
		"lineHeight",
		"textAlignHorizontal",
		"textAlignVertical",
		"textAutoResize",
		"effects",
		"layoutMode",
		"primaryAxisSizingMode",
		"counterAxisSizingMode",
		"primaryAxisAlignItems",
		"counterAxisAlignItems",
		"paddingLeft",
		"paddingRight",
		"paddingTop",
		"paddingBottom",
		"itemSpacing",
		"clipsContent",
		"backgrounds",
		"exportSettings",
		"constraints",
		"arcData",
		"dashPattern",
		"fillStyleId",
		"strokeStyleId",
		"effectStyleId",
		"textStyleId",
		"gridStyleId",
	];

	for (const prop of props) {
		try {
			// Check if the property exists on the current node type
			if (prop in node) {
				// Some properties like 'fills' can be completely empty or symbol-linked,
				// stringifying them handles the raw data structure gracefully.
				obj[prop] = node[prop];
			}
		} catch (e) {
			// Figma throws errors on certain getter properties if they don't apply
			// to the specific node (e.g. asking for fontName on a Rectangle)
			// We catch and ignore these silently.
		}
	}

	// Recursively extract properties from child nodes (for Frames, Groups, AutoLayouts)
	if ("children" in node && node.children) {
		obj.children = node.children.map((child) => serializeNode(child));
	}

	return obj;
}

// Function to process the current selection and update the UI
function handleSelectionChange() {
	const selection = figma.currentPage.selection;

	if (selection.length > 0) {
		// Convert the selected nodes into our JSON-friendly format
		const jsonData = selection.map((node) => serializeNode(node));

		// Send the data to the UI thread
		figma.ui.postMessage({
			type: "export-json",
			data: JSON.stringify(jsonData, null, 2),
		});
	} else {
		// Warn the user if nothing is selected
		figma.ui.postMessage({
			type: "error",
			message: "Please select at least one element on the canvas.",
		});
	}
}

// Run immediately on plugin start
handleSelectionChange();

// Listen for selection changes and update automatically
figma.on("selectionchange", handleSelectionChange);

// Listen for document changes (e.g., property updates) and update automatically
figma.on("documentchange", handleSelectionChange);
