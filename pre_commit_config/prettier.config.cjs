/** @type {import('prettier').Config} */

const config = {
    // https://github.com/prettier/prettier/issues/15388#issuecomment-1717746872
    plugins: [require.resolve("@prettier/plugin-xml")],
    printWidth: 120,

    //// JS config
    arrowParens: "avoid",
    bracketSpacing: true,
    bracketSameLine: false,
    proseWrap: "always",
    semi: true,
    trailingComma: "es5",

    //// XML config
    xmlSelfClosingSpace: true,
    tabWidth: 4,
    xmlWhitespaceSensitivity: "strict",
    overrides: [
        {
            files: "*.xml",
            options: {
                printWidth: 140,
            }
        },
        {
            files: ["**/views/menuitems.xml", "**/views/menu_items.xml"],
            options: {
                singleAttributePerLine: true,
            }
        }
    ],
};

module.exports = config;
